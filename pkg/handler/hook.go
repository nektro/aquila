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
	"github.com/nektro/aquila/pkg/handler/controls"
	"github.com/nektro/go-util/util"
	etc "github.com/nektro/go.etc"
	"github.com/nektro/go.etc/htp"
	"github.com/valyala/fastjson"
	"gopkg.in/yaml.v3"
)

func Hook(w http.ResponseWriter, r *http.Request) {
	c := htp.GetController(r)
	remo := controls.GetURemote(c, r)
	user := controls.GetUUser(c, r, remo)
	pkg := controls.GetUPackage(c, r, user)

	bys, _ := ioutil.ReadAll(r.Body)
	val, _ := fastjson.ParseBytes(bys)
	ref := string(val.GetStringBytes("ref"))
	branch := string(val.GetStringBytes("repository", "default_branch"))
	c.Assert(ref == "refs/heads/"+branch, "we're only packing new versions for commits to the default branch")

	secret := r.URL.Query().Get("secret")
	c.Assert(secret == pkg.HookSecret, "403: valid webhook secret required to push package updates")

	rnd := strconv.FormatInt(rand.Int63(), 10)[:6]
	os.Mkdir("/tmp/"+rnd, os.ModePerm)
	details := remo.GetRepoDetails(user, pkg.RemoteName)
	dir := "/tmp/" + rnd + "/" + details.Name
	fil := dir + ".tar.gz"

	cmd := exec.Command("git", "clone", details.CloneURL)
	cmd.Dir = "/tmp/" + rnd
	c.AssertNilErr(cmd.Run())

	zigmod, err := os.Open(dir + "/zig.mod")
	c.AssertNilErr(err)
	yamldec := yaml.NewDecoder(zigmod)
	var zigmodmod ZigModFile
	yamldec.Decode(&zigmodmod)
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

	c.Assert(db.Version{}.ByCommit(pkg, commit) == nil, "Version at this commit already created.")
	vnew := db.CreateVersion(pkg, commit, unpackedsize, totalsize, filelist, tarsize, tarhash, deps, devdeps)
	pkg.SetLicense(license)
	pkg.SetDescription(desc)

	vold := db.Version{}.GetLatestVersionOf(pkg)
	owner := db.User{}.ByUID(pkg.Owner)
	vnew.SetRealVer(owner, vold.RealMajor, vold.RealMinor+1)
	pkg.SetLatest(vnew)
}
