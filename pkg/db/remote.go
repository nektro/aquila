package db

import (
	"database/sql"
	"encoding/json"
	"io/ioutil"
	"log"
	"net/http"
	"strconv"
	"strings"

	dbstorage "github.com/nektro/go.dbstorage"
	"github.com/nektro/go.etc/dbt"
	"github.com/nektro/go.etc/store"
	"github.com/valyala/fastjson"
)

type Remote struct {
	ID     int64    `json:"id"`
	UUID   dbt.UUID `json:"uuid" dbsorm:"1"`
	Type   string   `json:"type" dbsorm:"1"`
	Domain string   `json:"domain" dbsorm:"1"`
}

// CreateRemote creates a new Remote
func CreateRemote(rtype string, domain string) *Remote {
	dbstorage.InsertsLock.Lock()
	defer dbstorage.InsertsLock.Unlock()

	id := db.QueryNextID(cTableRemotes)
	uid := dbt.NewUUID()
	n := &Remote{id, uid, rtype, domain}
	db.Build().InsI(cTableRemotes, n).Exe()
	return n
}

//
//

// Scan implements dbstorage.Scannable
func (v Remote) Scan(rows *sql.Rows) dbstorage.Scannable {
	rows.Scan(&v.ID, &v.UUID, &v.Type, &v.Domain)
	return &v
}

// All queries database for all currently existing Remotes
func (v Remote) All() []*Remote {
	arr := dbstorage.ScanAll(v.b(), Remote{})
	res := []*Remote{}
	for _, item := range arr {
		res = append(res, item.(*Remote))
	}
	return res
}

func (v Remote) ByDomain(domain string) *Remote {
	r, ok := dbstorage.ScanFirst(db.Build().Se("*").Fr(cTableRemotes).Wh("domain", domain), Remote{}).(*Remote)
	if !ok {
		return nil
	}
	return r
}

func (v Remote) ByID(id int64) *Remote {
	r, ok := dbstorage.ScanFirst(db.Build().Se("*").Fr(cTableRemotes).Wh("id", strconv.FormatInt(id, 10)), Remote{}).(*Remote)
	if !ok {
		return nil
	}
	return r
}

func (v Remote) IsValidType(rtype string) bool {
	switch rtype {
	case "github":
		return true
	}
	return false
}

//
//

func (v *Remote) i() string {
	return v.UUID.String()
}

func (v Remote) t() string {
	return cTableRemotes
}

func (v Remote) b() dbstorage.QueryBuilder {
	return db.Build().Se("*").Fr(v.t())
}

//
//

func (v *Remote) apiRoot() string {
	switch v.Type {
	case "github":
		return "https://api.github.com"
	}
	return ""
}

func (v *Remote) apiRequest(user *User, endpoint string) *fastjson.Value {
	req, _ := http.NewRequest(http.MethodGet, v.apiRoot()+endpoint, nil)
	if user != nil {
		if at := store.This.Get(user.UUID.String() + "_access_token"); len(at) > 0 {
			req.Header.Set("Authorization", "Bearer "+at)
		}
	}
	res, _ := http.DefaultClient.Do(req)
	if res.StatusCode >= 400 {
		bys, _ := ioutil.ReadAll(res.Body)
		log.Println(1, endpoint, res.StatusCode, string(bys))
		return nil
	}
	bys, _ := ioutil.ReadAll(res.Body)
	val, _ := fastjson.ParseBytes(bys)
	return val
}

func (v *Remote) apiPost(user *User, endpoint string, data string) *fastjson.Value {
	req, _ := http.NewRequest(http.MethodPost, v.apiRoot()+endpoint, strings.NewReader(data))
	if at := store.This.Get(user.UUID.String() + "_access_token"); len(at) > 0 {
		req.Header.Set("Authorization", "Bearer "+at)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/vnd.github.v3+json")
	res, _ := http.DefaultClient.Do(req)
	if res.StatusCode >= 400 {
		bys, _ := ioutil.ReadAll(res.Body)
		log.Println(2, endpoint, res.StatusCode, string(bys))
		return nil
	}
	bys, _ := ioutil.ReadAll(res.Body)
	val, _ := fastjson.ParseBytes(bys)
	return val
}

type RemoteRepo struct {
	ID    string
	Name  string
	Added bool
}

func (v *Remote) ListRemoteRepos(user *User) []RemoteRepo {
	ret := []RemoteRepo{}
	pkgs := user.GetPackages()
	switch v.Type {
	case "github":
		val := v.apiRequest(user, "/user/repos?per_page=100")
		for _, item := range val.GetArray() {
			id := strconv.FormatInt(item.GetInt64("id"), 10)
			name := string(item.GetStringBytes("full_name"))
			lang := string(item.GetStringBytes("language"))
			if lang == "Zig" {
				ret = append(ret, RemoteRepo{id, name, containsPackage(pkgs, id, name)})
			}
		}
	}
	return ret
}

func containsPackage(haystack []*Package, rmid string, rmname string) bool {
	for _, item := range haystack {
		if item.RemoteID == rmid && item.RemoteName == rmname {
			return true
		}
	}
	return false
}

type RepoDetails struct {
	ID          string
	Name        string
	CloneURL    string
	Description string
	MainBranch  string
	StarCount   int
}

func (v *Remote) GetRepoDetails(user *User, apipath string) *RepoDetails {
	switch v.Type {
	case "github":
		return v.GetRepoDetailsRaw(v.apiRequest(user, "/repos/"+apipath))
	}
	return nil
}

func (v *Remote) GetRepoDetailsRaw(val *fastjson.Value) *RepoDetails {
	switch v.Type {
	case "github":
		return &RepoDetails{
			strconv.FormatInt(val.GetInt64("id"), 10),
			string(val.GetStringBytes("name")),
			string(val.GetStringBytes("clone_url")),
			string(val.GetStringBytes("description")),
			string(val.GetStringBytes("default_branch")),
			val.GetInt("stargazers_count"),
		}
	}
	return nil
}

type githubWebhookConfig struct {
	Url         string   `json:"url"`
	Events      []string `json:"events"`
	Active      bool     `json:"active"`
	ContentType string   `json:"content_type"`
}

func (v *Remote) InstallWebhook(user *User, rid string, rname string, hookurl string) *fastjson.Value {
	switch v.Type {
	case "github":
		c := githubWebhookConfig{
			Url:         hookurl,
			Events:      []string{"push"},
			ContentType: "json",
			Active:      true,
		}
		bys, _ := json.Marshal(c)
		return v.apiPost(user, "/repos/"+rname+"/hooks", `{"name":"web","config":`+string(bys)+`}`)
	}
	return nil
}
