package handler

import (
	"net/http"

	"github.com/nektro/aquila/pkg/handler/controls"
	etc "github.com/nektro/go.etc"
	"github.com/nektro/go.etc/htp"
)

func Dashboard(w http.ResponseWriter, r *http.Request) {
	c := htp.GetController(r)
	user := controls.GetUser(c, r, w)
	remo := user.GetRemote()
	pkgs := user.GetPackages()

	writePageResponse(w, r, "/dashboard.hbs", map[string]interface{}{
		"aquila_version": etc.Version,
		"user":           user,
		"remote":         remo,
		"pkgs":           fixPackages(pkgs),
	})
}
