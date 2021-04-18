package handler

import (
	"net/http"

	etc "github.com/nektro/go.etc"
	"github.com/nektro/go.etc/htp"

	"github.com/nektro/aquila/pkg/db"
	"github.com/nektro/aquila/pkg/handler/controls"
)

func Approve(w http.ResponseWriter, r *http.Request) {
	c := htp.GetController(r)
	user := controls.GetUser(c, r, w)
	urepo := controls.GetURemote(c, r)
	uuser := controls.GetUUser(c, r, urepo)
	upkg := controls.GetUPackage(c, r, uuser)

	up := c.GetQueryString("up")
	c.Assert(up == "major" || up == "minor", "400: must pick between incrementing major or minor version")
	c.Assert(upkg.Owner == user.UUID, "400: must be the owner of this package to add new versions")

	writePageResponse(w, r, "/confirm.hbs", map[string]interface{}{
		"aquila_version": etc.Version,
		"user":           user,
		"message":        "Increment the " + up + " version",
		"endpoint":       r.URL.Path + "?" + r.URL.Query().Encode(),
	})
}

func ApprovePost(w http.ResponseWriter, r *http.Request) {
	c := htp.GetController(r)
	user := controls.GetUser(c, r, w)
	urepo := controls.GetURemote(c, r)
	uuser := controls.GetUUser(c, r, urepo)
	upkg := controls.GetUPackage(c, r, uuser)

	up := c.GetQueryString("up")
	c.Assert(up == "major" || up == "minor", "400: must pick between incrementing major or minor version")
	c.Assert(upkg.Owner == user.UUID, "400: must be the owner of this package to add new versions")

	old := db.Version{}.GetLatestVersionOff(upkg)
	new := db.Version{}.GetLatestVersionNew(upkg)
	c.Assert(new != nil, "400: no new versions to approve")

	if up == "major" {
		new.SetRealVer(user, old.RealMajor+1, 0)
	}
	if up == "minor" {
		new.SetRealVer(user, old.RealMajor, old.RealMinor+1)
	}
	new.ResetCreatedOn()

	w.Header().Set("location", "../"+upkg.Name)
	w.WriteHeader(http.StatusFound)
}
