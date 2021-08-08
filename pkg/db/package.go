package db

import (
	"database/sql"
	"strconv"
	"strings"

	"github.com/nektro/go-util/util"
	dbstorage "github.com/nektro/go.dbstorage"
	"github.com/nektro/go.etc/dbt"
)

type Package struct {
	ID            int64    `json:"id"`
	UUID          dbt.UUID `json:"uuid" dbsorm:"1"`
	Owner         dbt.UUID `json:"owner" dbsorm:"1"`
	Name          string   `json:"name" dbsorm:"1"`
	CreatedOn     dbt.Time `json:"created_on" dbsorm:"1"`
	Remote        int64    `json:"remote" dbsorm:"1"`
	RemoteID      string   `json:"remote_id" dbsorm:"1"`
	RemoteName    string   `json:"remote_name" dbsorm:"1"`
	Description   string   `json:"description" dbsorm:"1"`
	License       string   `json:"license" dbsorm:"1"`
	LatestVersion string   `json:"latest_version" dbsorm:"1"`
	hookSecret    string   `json:"hook_secret" dbsorm:"1"`
	StarCount     int      `json:"star_count" dbsorm:"1"`
}

// CreatePackage creates a new Package
func CreatePackage(owner *User, name string, remote int64, remoteID, remoteName, description, license string, starcount int) *Package {
	dbstorage.InsertsLock.Lock()
	defer dbstorage.InsertsLock.Unlock()
	//
	id := db.QueryNextID(cTablePackages)
	uid := dbt.NewUUID()
	co := now()
	hooksecret := strings.ToLower(util.RandomString(16))
	n := &Package{id, uid, owner.UUID, name, co, remote, remoteID, remoteName, description, license, "", hooksecret, starcount}
	db.Build().InsI(cTablePackages, n).Exe()
	return n
}

//
//

// Scan implements dbstorage.Scannable
func (v Package) Scan(rows *sql.Rows) dbstorage.Scannable {
	rows.Scan(&v.ID, &v.UUID, &v.Owner, &v.Name, &v.CreatedOn, &v.Remote, &v.RemoteID, &v.RemoteName, &v.Description, &v.License, &v.LatestVersion, &v.hookSecret, &v.StarCount)
	return &v
}

// All queries database for all currently existing Packages
func (v Package) All() []*Package {
	arr := dbstorage.ScanAll(v.b(), Package{})
	res := []*Package{}
	for _, item := range arr {
		res = append(res, item.(*Package))
	}
	return res
}

func (v Package) ByUser(user *User) []*Package {
	arr := dbstorage.ScanAll(v.b().Wh("owner", user.UUID.String()), Package{})
	res := []*Package{}
	for _, item := range arr {
		res = append(res, item.(*Package))
	}
	return res
}

func (v Package) ByUID(ulid dbt.UUID) *Package {
	us, ok := dbstorage.ScanFirst(v.b().Wh("uuid", string(ulid)), Package{}).(*Package)
	if !ok {
		return nil
	}
	return us
}

func (v Package) GetLatest(n int) []*Package {
	arr := dbstorage.ScanAll(v.b().Or("id", "desc").Lm(int64(n)), Package{})
	res := []*Package{}
	for _, item := range arr {
		res = append(res, item.(*Package))
	}
	return res
}

func (v Package) TopStarred(n int) []*Package {
	arr := dbstorage.ScanAll(v.b().Or("star_count", "desc").Lm(int64(n)), Package{})
	res := []*Package{}
	for _, item := range arr {
		res = append(res, item.(*Package))
	}
	return res
}

//
//

func (v *Package) i() string {
	return v.UUID.String()
}

func (v Package) t() string {
	return cTablePackages
}

func (v Package) b() dbstorage.QueryBuilder {
	return db.Build().Se("*").Fr(v.t())
}

//
//

func (v *Package) GetHookSecret() string {
	return v.hookSecret
}

func (v *Package) SetLatest(vers *Version) {
	vs := "v" + strconv.Itoa(vers.RealMajor) + "." + strconv.Itoa(vers.RealMinor)
	v.LatestVersion = vs
	doUp(v, "latest_version", "v"+strconv.Itoa(vers.RealMajor)+"."+strconv.Itoa(vers.RealMinor))
}

func (v *Package) GetVersion(major int, minor int) *Version {
	return Version{}.ByCode(v, major, minor)
}

func (v *Package) SetLicense(s string) {
	v.License = s
	doUp(v, "license", s)
}

func (v *Package) SetDescription(s string) {
	v.Description = s
	doUp(v, "description", s)
}

func (v *Package) SetStarCount(n int) {
	v.StarCount = n
	doUp(v, "star_count", strconv.Itoa(n))
}
