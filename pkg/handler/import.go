package handler

import (
	"net/http"

	"github.com/nektro/aquila/pkg/handler/controls"
	etc "github.com/nektro/go.etc"
	"github.com/nektro/go.etc/htp"
)

func Import(w http.ResponseWriter, r *http.Request) {
	c := htp.GetController(r)
	user := controls.GetUser(c, r, w)
	remo := user.GetRemote()
	list := remo.ListRemoteRepos(user)

	writePageResponse(w, r, "/import.hbs", map[string]interface{}{
		"aquila_version": etc.Version,
		"user":           user,
		"remote":         remo,
		"list":           list,
	})
}
