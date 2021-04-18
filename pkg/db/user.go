package db

import (
	"database/sql"

	dbstorage "github.com/nektro/go.dbstorage"
	"github.com/nektro/go.etc/dbt"
)

type User struct {
	ID        int64    `json:"id"`
	UUID      dbt.UUID `json:"uuid" dbsorm:"1"`
	Provider  int64    `json:"provider" dbsorm:"1"`
	Snowflake string   `json:"snowflake" dbsorm:"1"`
	Name      string   `json:"name" dbsorm:"1"`
	JoindedOn dbt.Time `json:"joined_on" dbsorm:"1"`
}

//
//

// Scan implements dbstorage.Scannable
func (v User) Scan(rows *sql.Rows) dbstorage.Scannable {
	rows.Scan(&v.ID, &v.UUID, &v.Provider, &v.Snowflake, &v.Name, &v.JoindedOn)
	return &v
}

// All queries database for all currently existing Users
func (v User) All() []*User {
	arr := dbstorage.ScanAll(v.b(), User{})
	res := []*User{}
	for _, item := range arr {
		res = append(res, item.(*User))
	}
	return res
}

func (v User) BySnowflake(provider int64, snowflake string, name string) *User {
	us, ok := dbstorage.ScanFirst(v.b().Wh("provider", format(provider)).Wh("snowflake", snowflake), User{}).(*User)
	if ok {
		return us
	}
	dbstorage.InsertsLock.Lock()
	defer dbstorage.InsertsLock.Unlock()
	//
	id := db.QueryNextID(cTableUsers)
	uid := dbt.NewUUID()
	co := now()
	n := &User{id, uid, provider, snowflake, name, co}
	db.Build().InsI(cTableUsers, n).Exe()
	return n
}

func (v User) ByUID(ulid dbt.UUID) *User {
	us, ok := dbstorage.ScanFirst(v.b().Wh("uuid", string(ulid)), User{}).(*User)
	if !ok {
		return nil
	}
	return us
}

func (v User) ByName(remote int64, name string) *User {
	us, ok := dbstorage.ScanFirst(v.b().Wh("provider", format(remote)).Wh("name", name), User{}).(*User)
	if !ok {
		return nil
	}
	return us
}

//
//

func (v *User) i() string {
	return v.UUID.String()
}

func (v User) t() string {
	return cTableUsers
}

func (v User) b() dbstorage.QueryBuilder {
	return db.Build().Se("*").Fr(v.t())
}

//
//

func (v *User) GetRemote() *Remote {
	return Remote{}.ByID(v.Provider)
}

func (v *User) GetPackages() []*Package {
	return Package{}.ByUser(v)
}

func (v *User) GetPackageByName(name string) *Package {
	for _, item := range v.GetPackages() {
		if item.Name == name {
			return item
		}
	}
	return nil
}
