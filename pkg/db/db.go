package db

import (
	"strconv"
	"time"

	dbstorage "github.com/nektro/go.dbstorage"
	etc "github.com/nektro/go.etc"
	"github.com/nektro/go.etc/dbt"
)

var (
	db dbstorage.Database
)

var (
	cTableRemotes  = "remotes"
	cTableUsers    = "users"
	cTablePackages = "packages"
	cTableVersions = "versions"
)

func Init() {
	db = etc.Database

	db.CreateTableStruct("remotes", Remote{})
	db.CreateTableStruct("users", User{})
	db.CreateTableStruct("packages", Package{})
	db.CreateTableStruct("versions", Version{})
	db.CreateTableStruct("versions_rejected", Version{})
}

func Close() {
	db.Close()
}

func now() dbt.Time {
	s := time.Now().UTC().String()[0:19]
	t, _ := time.Parse(dbt.TimeFormat, s)
	return dbt.Time(t)
}

func format(i int64) string {
	return strconv.FormatInt(i, 10)
}

type IIDers interface {
	t() string
	i() string
}

func doUp(v IIDers, col string, value string) {
	db.Build().Up(v.t(), col, value).Wh("uuid", v.i()).Exe()
}

func doDel(v IIDers) {
	db.Build().Del(v.t()).Wh("uuid", v.i()).Exe()
}

func atoi(s string) int {
	i, _ := strconv.Atoi(s)
	return i
}
