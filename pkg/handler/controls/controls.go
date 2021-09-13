package controls

import (
	"net/http"
	"strconv"

	"github.com/gorilla/mux"
	"github.com/nektro/aquila/pkg/db"
	"github.com/nektro/go-util/arrays/stringsu"
	etc "github.com/nektro/go.etc"
	"github.com/nektro/go.etc/dbt"
	"github.com/nektro/go.etc/htp"
	"github.com/nektro/go.etc/jwt"
)

var formMethods = []string{http.MethodPost, http.MethodPut, http.MethodPatch, http.MethodDelete}

// GetUser asserts a user is logged in
func GetUser(c *htp.Controller, r *http.Request, w http.ResponseWriter) *db.User {
	l := etc.JWTGetClaims(c, r)

	userID := l["sub"].(string)
	user := db.User{}.ByUID(dbt.UUID(userID))
	c.Assert(user != nil, "500: unable to find user: "+userID)

	method := r.Method
	if stringsu.Contains(formMethods, method) {
		r.Method = http.MethodPost
		r.ParseMultipartForm(0)
		r.Method = method
	}

	w.Header().Add("x-m-jwt-iss", l["iss"].(string))
	w.Header().Add("x-m-jwt-sub", l["sub"].(string))

	return user
}

func GetUserOptional(r *http.Request) *db.User {
	clms, err := jwt.VerifyRequest(r, etc.JWTSecret)
	if err != nil {
		return nil
	}
	userID := clms["sub"].(string)
	return db.User{}.ByUID(dbt.UUID(userID))
}

func GetUrlVar(c *htp.Controller, r *http.Request, key string) string {
	s, ok := mux.Vars(r)[key]
	c.Assert(ok, "400: key "+key+" not found in the requested url path")
	return s
}

func GetUrlInt(c *htp.Controller, r *http.Request, key string) int64 {
	s := GetUrlVar(c, r, key)
	i, err := strconv.ParseInt(s, 10, 64)
	c.AssertNilErr(err)
	return i
}

func GetURemote(c *htp.Controller, r *http.Request) *db.Remote {
	x := db.Remote{}.ByID(GetUrlInt(c, r, "repo"))
	c.Assert(x != nil, "404: A remote by the requested name cannot be found.")
	return x
}

func GetUUser(c *htp.Controller, r *http.Request, repo *db.Remote) *db.User {
	x := db.User{}.ByName(repo.ID, GetUrlVar(c, r, "user"))
	c.Assert(x != nil, "404: A user by the requested name cannot be found.")
	return x
}

func GetUPackage(c *htp.Controller, r *http.Request, owner *db.User) *db.Package {
	x := owner.GetPackageByName(GetUrlVar(c, r, "package"))
	c.Assert(x != nil, "404: A package by the requested name cannot be found.")
	return x
}

func GetUVersion(c *htp.Controller, r *http.Request, pkg *db.Package) *db.Version {
	mj := GetUrlInt(c, r, "major")
	mn := GetUrlInt(c, r, "minor")
	x := pkg.GetVersion(int(mj), int(mn))
	c.Assert(x != nil, "404: A version by the requested name cannot be found.")
	return x
}
