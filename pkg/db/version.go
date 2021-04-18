package db

import (
	"database/sql"
	"strconv"

	dbstorage "github.com/nektro/go.dbstorage"
	"github.com/nektro/go.etc/dbt"
)

type Version struct {
	ID           int64     `json:"id"`
	UUID         dbt.UUID  `json:"uuid" dbsorm:"1"`
	For          dbt.UUID  `json:"p_for" dbsorm:"1"`
	CreatedOn    dbt.Time  `json:"created_on" dbsorm:"1"`
	CommitTo     string    `json:"commit_to" dbsorm:"1"`
	UnpackedSize int64     `json:"unpacked_size" dbsorm:"1"`
	TotalSize    int64     `json:"total_size" dbsorm:"1"`
	Files        dbt.Array `json:"files" dbsorm:"1"`
	TarSize      int64     `json:"tar_size" dbsorm:"1"`
	TarHash      string    `json:"tar_hash" dbsorm:"1"`
	ApprovedBy   dbt.UUID  `json:"approved_by" dbsorm:"1"`
	RealMajor    int       `json:"real_major" dbsorm:"1"`
	RealMinor    int       `json:"real_minor" dbsorm:"1"`
	Deps         dbt.Array `json:"deps" dbsorm:"1"`
	DevDeps      dbt.Array `json:"dev_deps" dbsorm:"1"`
}

//
//

// CreateVersion creates a new Version
func CreateVersion(p *Package, cto string, ups int64, tts int64, files []string, trs int64, trh string, deps []string, devdeps []string) *Version {
	dbstorage.InsertsLock.Lock()
	defer dbstorage.InsertsLock.Unlock()
	//
	id := db.QueryNextID(cTableVersions)
	uid := dbt.NewUUID()
	co := now()
	n := &Version{id, uid, p.UUID, co, cto, ups, tts, files, trs, trh, dbt.UUID(""), 0, 0, deps, devdeps}
	db.Build().InsI(cTableVersions, n).Exe()
	return n
}

//
//

// Scan implements dbstorage.Scannable
func (v Version) Scan(rows *sql.Rows) dbstorage.Scannable {
	rows.Scan(&v.ID, &v.UUID, &v.For, &v.CreatedOn, &v.CommitTo, &v.UnpackedSize, &v.TotalSize, &v.Files, &v.TarSize, &v.TarHash, &v.ApprovedBy, &v.RealMajor, &v.RealMinor, &v.Deps, &v.DevDeps)
	return &v
}

// All queries database for all currently existing Versions
func (v Version) All() []*Version {
	arr := dbstorage.ScanAll(v.b(), Version{})
	res := []*Version{}
	for _, item := range arr {
		res = append(res, item.(*Version))
	}
	return res
}

func (v Version) ActiveByPackage(p *Package) []*Version {
	arr := dbstorage.ScanAll(v.b().Wh("p_for", p.UUID.String()), Version{})
	res := []*Version{}
	for _, item := range arr {
		x := item.(*Version)
		if x.RealMajor == 0 && x.RealMinor == 0 {
			continue
		}
		res = append(res, x)
	}
	return res
}

func (v Version) NewByPackage(p *Package) []*Version {
	arr := dbstorage.ScanAll(v.b().Wh("p_for", p.UUID.String()).Wh("real_major", "0").Wh("real_minor", "0"), Version{})
	res := []*Version{}
	for _, item := range arr {
		res = append(res, item.(*Version))
	}
	return res
}

func (v Version) ByCode(p *Package, major int, minor int) *Version {
	x, ok := dbstorage.ScanFirst(v.b().Wh("p_for", p.UUID.String()).Wh("real_major", strconv.Itoa(major)).Wh("real_minor", strconv.Itoa(minor)), Version{}).(*Version)
	if !ok {
		return nil
	}
	return x
}

func (v Version) GetLatest(n int) []*Version {
	arr := dbstorage.ScanAll(v.b().Or("id", "desc").Lm(int64(n)), Version{})
	res := []*Version{}
	for _, item := range arr {
		res = append(res, item.(*Version))
	}
	return res
}

func (v Version) ByCommit(p *Package, c string) *Version {
	x, ok := dbstorage.ScanFirst(v.b().Wh("commit_to", c), Version{}).(*Version)
	if !ok {
		return nil
	}
	return x
}

//
//

func (v *Version) i() string {
	return v.UUID.String()
}

func (v Version) t() string {
	return cTableVersions
}

func (v Version) b() dbstorage.QueryBuilder {
	return db.Build().Se("*").Fr(v.t())
}

//
//

func (v *Version) SetRealVer(approver *User, major int, minor int) {
	v.ApprovedBy = approver.UUID
	doUp(v, "approved_by", approver.UUID.String())
	v.RealMajor = major
	doUp(v, "real_major", strconv.Itoa(major))
	v.RealMinor = minor
	doUp(v, "real_minor", strconv.Itoa(minor))
}
