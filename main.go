package main

import (
	"fmt"
	"io/ioutil"
	"log"
	"math/rand"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/aymerick/raymond"
	"github.com/nektro/go-util/util"
	"github.com/nektro/go-util/vflag"
	etc "github.com/nektro/go.etc"
	"github.com/nektro/go.etc/dbt"
	"github.com/nektro/go.etc/store"
	oauth2 "github.com/nektro/go.oauth2"

	"github.com/nektro/aquila/pkg/db"
	"github.com/nektro/aquila/pkg/global"
	"github.com/nektro/aquila/pkg/handler"

	_ "github.com/nektro/aquila/statik"
)

// Version takes in version string from build_all.sh
var Version = "vMASTER"
var Name = "Aquila"

func main() {
	//
	rand.Seed(time.Now().UnixNano())

	etc.AppID = strings.ToLower(Name)
	etc.Version = Version
	etc.FixBareVersion()
	etc.Version = strings.ReplaceAll(etc.Version, "-", ".")
	util.Log("Starting " + Name + " " + etc.Version + ".")

	{
		p := oauth2.ProviderIDMap["github"]
		p.ID = "github.com"
		p.Scope += " write:repo_hook"
		oauth2.ProviderIDMap["github"] = p
		oauth2.ProviderIDMap["_github"] = p
		oauth2.ProviderIDMap["github.com"] = p
	}

	vflag.StringVar(&global.Domain, "domain", "", "")

	etc.PreInit()
	etc.Init(&global.Config, "./dashboard", handler.SaveOAuth2InfoCb)

	util.DieOnError(util.Assert(len(global.Domain) > 0, "--domain must be set to the hostname of this server"))

	dbversionpath := etc.DataRoot() + "/migration_version.txt"
	if !util.DoesFileExist(dbversionpath) {
		f, _ := os.Create(dbversionpath)
		defer f.Close()
		fmt.Fprint(f, 1)
		global.DbRev = 1
	} else {
		f, _ := os.Open(dbversionpath)
		defer f.Close()
		data, _ := ioutil.ReadAll(f)
		num, _ := strconv.ParseInt(string(data), 10, 32)
		global.DbRev = num
	}
	util.Log("db: schema revision:", global.DbRev)

	store.Init("local", "")
	db.Init()

	for _, item := range global.Config.Clients {
		rtype := item.For
		domain := item.For
		if strings.Contains(domain, "(") {
			rtype = rtype[:strings.Index(rtype, "(")]
			domain = domain[strings.Index(domain, "(")+1:]
			domain = domain[:len(domain)-1]
		}
		if (db.Remote{}.ByDomain(domain) == nil) {
			rtype = strings.TrimSuffix(rtype, ".com")
			util.DieOnError(util.Assert(db.Remote{}.IsValidType(rtype), rtype+" is not a supported oauth2 client type"))
			r := db.CreateRemote(rtype, domain)
			log.Println("registered new remote:", r.ID, rtype, domain)
		}
	}

	switch global.DbRev {
	case 1:
		{
			// approve all versions
			for _, item := range (db.Package{}.All()) {
				verified := db.Version{}.ActiveByPackage_(item)
				latest := verified[len(verified)-1].RealMinor
				owner := db.User{}.ByUID(item.Owner)
				maj := verified[len(verified)-1].RealMajor
				majs := strconv.Itoa(maj)

				for _, jtem := range (db.Version{}.NewByPackage_(item)) {
					latest += 1
					jtem.SetRealVer(owner, maj, latest)
					latests := strconv.Itoa(latest)
					util.Log("migrate:", "auto-approved:", string(item.UUID), "-", item.Name, "to", "v"+majs+"."+latests)
				}
			}
			global.DbRev += 1
		}
		fallthrough
	case 2:
		{
			// import star count
			for _, item := range (db.Package{}.All()) {
				remo := db.Remote{}.ByID(item.Remote)
				dets := remo.GetRepoDetails(nil, item.RemoteName)
				item.SetStarCount(dets.StarCount)
				util.Log("migrate:", "star-count:", remo.Domain+"/"+item.RemoteName, dets.StarCount)
				time.Sleep(time.Second)
			}
			global.DbRev += 1
		}
	}
	util.Log("db: schema revision:", global.DbRev)
	f, _ := os.Create(dbversionpath)
	fmt.Fprint(f, global.DbRev)
	f.Close()

	util.RunOnClose(func() {
		util.Log("Gracefully shutting down...")

		util.Log("Saving database to disk")
		db.Close()

		util.Log("Done")
		os.Exit(0)
	})

	raymond.RegisterHelper("fix_date", func(s string) string {
		t, err := time.Parse(time.RFC3339, s)
		if err != nil {
			return ""
		}
		return t.Format(time.RFC1123)
	})
	raymond.RegisterHelper("fix_bytes", func(b int64) string {
		return util.ByteCountIEC(b)
	})
	raymond.RegisterHelper("trim_str", func(s string, n int) string {
		return s[:n]
	})
	raymond.RegisterHelper("get_user_path", func(p dbt.UUID) string {
		u := db.User{}.ByUID(p)
		return strconv.FormatInt(u.Provider, 10) + "/" + u.Name
	})
	raymond.RegisterHelper("versionp_str", func(p *db.Version) string {
		return "v" + strconv.Itoa(p.RealMajor) + "." + strconv.Itoa(p.RealMinor)
	})
	raymond.RegisterHelper("version_str", func(p db.Version) string {
		return "v" + strconv.Itoa(p.RealMajor) + "." + strconv.Itoa(p.RealMinor)
	})
	raymond.RegisterHelper("tree_url", func(rem int64, name string, commit string) string {
		return "https://github.com/" + name + "/tree/" + commit
	})
	raymond.RegisterHelper("diff_url", func(r int64, n string, x int, to string, newv []*db.Version, appv []*db.Version) string {
		from := ""
		if x == 0 {
			from = appv[len(appv)-1].CommitTo
		} else {
			from = newv[x-1].CommitTo
		}
		return "https://github.com/" + n + "/compare/" + from[:10] + "..." + to[:10]
	})
	raymond.RegisterHelper("prev_commit", func(x int, newv []*db.Version, appv []*db.Version) string {
		if x == 0 {
			return appv[len(appv)-1].CommitTo[:8]
		}
		return newv[x-1].CommitTo[:8]
	})
	raymond.RegisterHelper("notequal", func(a interface{}, b interface{}, options *raymond.Options) interface{} {
		if raymond.Str(a) == raymond.Str(b) {
			return options.Inverse()
		}
		return options.Fn()
	})
	raymond.RegisterHelper("diff_url_off", func(r int64, n string, x int, to string, appv []*db.Version) string {
		return "https://github.com/" + n + "/compare/" + appv[x-1].CommitTo[:10] + "..." + to[:10]
	})
	raymond.RegisterHelper("prev_commit_off", func(x int, appv []*db.Version) string {
		return appv[x-1].CommitTo[:8]
	})
	raymond.RegisterHelper("version_path", func(p *db.Version) string {
		g := db.Package{}.ByUID(p.For)
		u := db.User{}.ByUID(g.Owner)
		return fmt.Sprintf("%d/%s/%s", g.Remote, u.Name, g.Name)
	})
	raymond.RegisterHelper("version_pkg_description", func(p *db.Version) string {
		return (db.Package{}.ByUID(p.For)).Description
	})
	raymond.RegisterHelper("version_pkg_stars", func(p *db.Version) int {
		return (db.Package{}.ByUID(p.For)).StarCount
	})
	raymond.RegisterHelper("pkg_is_github", func(id dbt.UUID, options *raymond.Options) string {
		p := db.Package{}.ByUID(id)
		r := db.Remote{}.ByID(p.Remote)
		if r.Domain == "github.com" {
			return options.Fn()
		}
		return ""
	})

	handler.Init()

	etc.StartServer()
}
