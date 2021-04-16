package main

import (
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
	raymond.RegisterHelper("version_str", func(p db.Version) string {
		return "v" + strconv.Itoa(p.RealMajor) + "." + strconv.Itoa(p.RealMinor)
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

	handler.Init()

	etc.StartServer()
}
