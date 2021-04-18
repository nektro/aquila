package handler

import (
	"net/http"

	"github.com/nektro/aquila/pkg/db"
	"github.com/nektro/aquila/pkg/handler/controls"
	etc "github.com/nektro/go.etc"
	"github.com/nektro/go.etc/htp"
)

func Reject(w http.ResponseWriter, r *http.Request) {
	c := htp.GetController(r)
	user := controls.GetUser(c, r, w)
	urepo := controls.GetURemote(c, r)
	uuser := controls.GetUUser(c, r, urepo)
	upkg := controls.GetUPackage(c, r, uuser)

	c.Assert(upkg.Owner == user.UUID, "400: must be the owner of this package to remove new versions")

	writePageResponse(w, r, "/confirm.hbs", map[string]interface{}{
		"aquila_version": etc.Version,
		"user":           user,
		"message":        "Remove the pending version",
		"endpoint":       r.URL.Path + "?" + r.URL.Query().Encode(),
	})
}

func RejectPost(w http.ResponseWriter, r *http.Request) {
	c := htp.GetController(r)
	user := controls.GetUser(c, r, w)
	urepo := controls.GetURemote(c, r)
	uuser := controls.GetUUser(c, r, urepo)
	upkg := controls.GetUPackage(c, r, uuser)

	c.Assert(upkg.Owner == user.UUID, "400: must be the owner of this package to remove new versions")

	new := db.Version{}.GetLatestVersionNew(upkg)
	c.Assert(new != nil, "400: no new versions to approve")

	new.Delete()

	w.Header().Set("location", "../"+upkg.Name)
	w.WriteHeader(http.StatusFound)
}
