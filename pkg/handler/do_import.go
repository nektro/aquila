package handler

import (
	"archive/tar"
	"compress/gzip"
	"io/ioutil"
	"math/rand"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/nektro/aquila/pkg/db"
	"github.com/nektro/aquila/pkg/global"
	"github.com/nektro/aquila/pkg/handler/controls"
	"github.com/nektro/go-util/util"
	etc "github.com/nektro/go.etc"
	"github.com/nektro/go.etc/htp"
	"gopkg.in/yaml.v3"
)

func DoImport(w http.ResponseWriter, r *http.Request) {
	c := htp.GetController(r)
	user := controls.GetUser(c, r, w)
	remo := user.GetRemote()
	pkgs := user.GetPackages()

	repo := r.URL.Query().Get("repo")

	for _, item := range pkgs {
		if item.Remote == remo.ID && item.RemoteName == repo {
			writeAPIResponse(r, w, true, false, http.StatusBadRequest, "Repository "+repo+" has already been initialized.")
			return
		}
	}

	rnd := strconv.FormatInt(rand.Int63(), 10)[:6]
	os.Mkdir("/tmp/"+rnd, os.ModePerm)
	details := remo.GetRepoDetails(user, repo)
	dir := "/tmp/" + rnd + "/" + details.Name
	fil := dir + ".tar.gz"

	cmd := exec.Command("git", "clone", details.CloneURL)
	cmd.Dir = "/tmp/" + rnd
	if err := cmd.Run(); err != nil {
		writeAPIResponse(r, w, true, false, http.StatusInternalServerError, err.Error())
		return
	}

	zigmod, err := os.Open(dir + "/zig.mod")
	c.AssertNilErr(err)
	yamldec := yaml.NewDecoder(zigmod)
	var zigmodmod ZigModFile
	yamldec.Decode(&zigmodmod)
	name := zigmodmod.Name
	license := zigmodmod.License
	desc := zigmodmod.Description
	if len(desc) == 0 {
		desc = details.Description
	}
	deps := []string{}
	for _, item := range zigmodmod.Deps {
		dtype := item.Type
		dpath := item.Path
		dvers := item.Version
		for i, item := range strings.Fields(item.Src) {
			switch i {
			case 0:
				dtype = item
			case 1:
				dpath = item
			case 2:
				dvers = item
			}
		}
		deps = append(deps, dtype+" "+dpath+" "+dvers)
	}
	devdeps := []string{}
	for _, item := range zigmodmod.DevDeps {
		dtype := item.Type
		dpath := item.Path
		dvers := item.Version
		for i, item := range strings.Fields(item.Src) {
			switch i {
			case 0:
				dtype = item
			case 1:
				dpath = item
			case 2:
				dvers = item
			}
		}
		devdeps = append(devdeps, dtype+" "+dpath+" "+dvers)
	}

	cmd = exec.Command("git", "rev-parse", "HEAD")
	cmd.Dir = dir
	bs, err := cmd.Output()
	c.AssertNilErr(err)
	commit := string(bs)[:len(bs)-1]
	os.RemoveAll(dir + "/.git")
	unpackedsize := dirSize(dir)

	cmd = exec.Command("zigmod", "fetch")
	cmd.Dir = dir
	c.AssertNilErr(cmd.Run())
	os.Remove(dir + "/deps.zig")
	totalsize := dirSize(dir)
	os.RemoveAll(dir + "/.zigmod")

	filelist := []string{}

	tarf, _ := os.Create(fil)
	gzw := gzip.NewWriter(tarf)
	tarw := tar.NewWriter(gzw)
	filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
		if info.IsDir() {
			return nil
		}
		filelist = append(filelist, path[len(dir)+1:])
		tarw.WriteHeader(&tar.Header{
			Name: path[len(dir)+1:],
			Size: info.Size(),
			Mode: int64(os.ModePerm),
		})
		bys, _ := ioutil.ReadFile(path)
		tarw.Write(bys)
		return nil
	})
	tarw.Close()
	gzw.Close()
	tarf.Close()
	tarf, _ = os.Open(fil)
	tarsize := fileSize(fil)
	tarhash := "sha256-" + strings.ToLower(util.HashStream("SHA256", tarf))
	dirr := etc.DataRoot() + "/packages/" + user.UUID.String() + "/" + details.ID
	c.AssertNilErr(os.MkdirAll(dirr, os.ModePerm))
	c.AssertNilErr(copyFile(fil, dirr+"/"+commit+".tar.gz"))

	p := db.CreatePackage(user, name, remo.ID, details.ID, repo, desc, license, details.StarCount)
	v := db.CreateVersion(p, commit, unpackedsize, totalsize, filelist, tarsize, tarhash, deps, devdeps)
	v.SetRealVer(user, 0, 1)
	p.SetLatest(v)
	desturl := "/" + strconv.FormatInt(remo.ID, 10) + "/" + user.Name + "/" + name

	remo.InstallWebhook(user, details.ID, repo, "https://"+global.Domain+desturl+"/hook?secret="+p.HookSecret)

	w.Header().Add("Location", "."+desturl)
	w.WriteHeader(http.StatusFound)
}
