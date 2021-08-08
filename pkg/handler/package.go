package handler

import (
	"net/http"

	"github.com/nektro/aquila/pkg/db"
	"github.com/nektro/aquila/pkg/handler/controls"
	etc "github.com/nektro/go.etc"
	"github.com/nektro/go.etc/htp"
)

func Package(w http.ResponseWriter, r *http.Request) {
	c := htp.GetController(r)
	user := controls.GetUserOptional(r)
	repo := controls.GetURemote(c, r)
	owner := controls.GetUUser(c, r, repo)
	pkg := controls.GetUPackage(c, r, owner)

	writePageResponse(w, r, "/package.hbs", map[string]interface{}{
		"aquila_version": etc.Version,
		"user":           user,
		"repo":           repo,
		"owner":          owner,
		"pkg":            pkg,
		"versions":       db.Version{}.AllByPackage(pkg),
	})
}
