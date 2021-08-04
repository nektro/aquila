package handler

import (
	"net/http"

	"github.com/nektro/aquila/pkg/handler/controls"
	etc "github.com/nektro/go.etc"
	"github.com/nektro/go.etc/htp"
)

func User(w http.ResponseWriter, r *http.Request) {
	c := htp.GetController(r)
	user := controls.GetUserOptional(r)
	repo := controls.GetURemote(c, r)
	owner := controls.GetUUser(c, r, repo)

	writePageResponse(w, r, "/user.hbs", map[string]interface{}{
		"aquila_version": etc.Version,
		"user":           user,
		"repo":           repo,
		"powner":         owner,
		"pkgs":           owner.GetPackages(),
	})
}
