package handler

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strconv"

	"github.com/nektro/aquila/pkg/db"
	etc "github.com/nektro/go.etc"
	"github.com/nektro/go.etc/htp"
	"github.com/nektro/go.etc/store"
)

func SaveOAuth2InfoCb(w http.ResponseWriter, r *http.Request, provider string, id string, name string, resp map[string]interface{}) {
	rm := db.Remote{}.ByDomain(provider)
	ru := db.User{}.BySnowflake(rm.ID, id, name)
	log.Println("[user-login]", provider, id, ru.UUID, ru.Name)
	etc.JWTSet(w, ru.UUID.String())
	store.This.Set(ru.UUID.String()+"_access_token", resp["access_token"].(string))
}

func Init() {
	etc.HtpErrCb = func(r *http.Request, w http.ResponseWriter, good bool, code int, data string) {
		if data == "astheno/jwt: token: token contains an invalid number of segments" ||
			data == "astheno/jwt: token: signature is invalid" {
			w.Header().Add("Location", "./login")
			w.WriteHeader(http.StatusFound)
			return
		}
		writeAPIResponse(r, w, r.Header.Get("accept") != "application/json", good, code, data)
	}

	//
	htp.Register("/", http.MethodGet, Index)
	htp.Register("/about", http.MethodGet, Static("about"))
	htp.Register("/contact", http.MethodGet, Static("contact"))
	htp.Register("/dashboard", http.MethodGet, Dashboard)
	htp.Register("/import", http.MethodGet, Import)
	htp.Register("/do_import", http.MethodGet, DoImport)
	htp.Register("/{repo:[0-9]+}/{user}", http.MethodGet, User)
	htp.Register("/{repo:[0-9]+}/{user}/{package}", http.MethodGet, Package)
	htp.Register("/{repo:[0-9]+}/{user}/{package}/v{major:[0-9]+}.{minor:[0-9]+}", http.MethodGet, Version)
	htp.Register("/{repo:[0-9]+}/{user}/{package}/v{major:[0-9]+}.{minor:[0-9]+}.tar.gz", http.MethodGet, VersionDL)
	htp.Register("/{repo:[0-9]+}/{user}/{package}/hook", http.MethodPost, Hook)
	htp.Register("/{repo:[0-9]+}/{user}/{package}/approve", http.MethodGet, Approve)
	htp.Register("/{repo:[0-9]+}/{user}/{package}/approve", http.MethodPost, ApprovePost)
	htp.Register("/{repo:[0-9]+}/{user}/{package}/reject", http.MethodGet, Reject)
	htp.Register("/{repo:[0-9]+}/{user}/{package}/reject", http.MethodPost, RejectPost)

	htp.Register("/.well-known/aquila", http.MethodGet, func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "https://github.com/nektro/aquila")
		fmt.Fprintln(w, etc.Version)
	})
}

type ZigModFile struct {
	Name        string   `yaml:"name"`
	License     string   `yaml:"license"`
	Description string   `yaml:"description"`
	Deps        []ZigDep `yaml:"dependencies"`
	DevDeps     []ZigDep `yaml:"dev_dependencies"`
}

type ZigDep struct {
	Type    string `yaml:"type"`
	Path    string `yaml:"path"`
	Version string `yaml:"version"`
	Src     string `yaml:"src"`
}

func writeAPIResponse(r *http.Request, w http.ResponseWriter, asHtml bool, good bool, status int, message interface{}) {
	resp := map[string]interface{}{
		"aquila_version": etc.Version,
		"success":        good,
		"status":         status,
		"message":        message,
	}
	if asHtml {
		writePageResponse(w, r, "/response.hbs", resp)
		return
	}
	w.Header().Add("content-type", "application/json")
	dat, _ := json.Marshal(resp)
	fmt.Fprintln(w, string(dat))
}

func writePageResponse(w http.ResponseWriter, r *http.Request, page string, data map[string]interface{}) {
	if r.Header.Get("accept") == "application/json" {
		w.Header().Add("content-type", "application/json")
		bys, _ := json.Marshal(data)
		fmt.Fprintln(w, string(bys))
		return
	}
	etc.WriteHandlebarsFile(r, w, page, data)
}

func dirSize(dirpath string) int64 {
	ret := int64(0)
	filepath.Walk(dirpath, func(path string, info os.FileInfo, err error) error {
		if info.IsDir() {
			return nil
		}
		ret += info.Size()
		return nil
	})
	return ret
}

func fileSize(filepath string) int64 {
	info, _ := os.Stat(filepath)
	return info.Size()
}

func copyFile(src string, dest string) error {
	existing, err := os.Open(src)
	if err != nil {
		return err
	}
	defer existing.Close()
	newfile, err := os.Create(dest)
	if err != nil {
		return err
	}
	defer newfile.Close()
	_, err = io.Copy(newfile, existing)
	if err != nil {
		return err
	}
	return nil
}

func atoi(s string) int {
	i, _ := strconv.Atoi(s)
	return i
}
