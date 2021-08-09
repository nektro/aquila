package handler

import (
	"net/http"

	"github.com/nektro/aquila/pkg/db"
	"github.com/nektro/aquila/pkg/handler/controls"
	etc "github.com/nektro/go.etc"
	"github.com/nektro/go.etc/htp"
)

func Version(w http.ResponseWriter, r *http.Request) {
	c := htp.GetController(r)
	user := controls.GetUserOptional(r)
	repo := controls.GetURemote(c, r)
	owner := controls.GetUUser(c, r, repo)
	pkg := controls.GetUPackage(c, r, owner)
	vers := controls.GetUVersion(c, r, pkg)

	writePageResponse(w, r, "/version.hbs", map[string]interface{}{
		"aquila_version": etc.Version,
		"user":           user,
		"repo":           repo,
		"owner":          owner,
		"pkg":            fixPackage(pkg),
		"vers":           vers,
		"approver":       db.User{}.ByUID(vers.ApprovedBy),
	})
}

func VersionDL(w http.ResponseWriter, r *http.Request) {
	c := htp.GetController(r)
	repo := controls.GetURemote(c, r)
	owner := controls.GetUUser(c, r, repo)
	pkg := controls.GetUPackage(c, r, owner)
	vers := controls.GetUVersion(c, r, pkg)
	http.ServeFile(w, r, etc.DataRoot()+"/packages/"+owner.UUID.String()+"/"+pkg.RemoteID+"/"+vers.CommitTo+".tar.gz")
}
