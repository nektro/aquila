package handler

import (
	"net/http"

	"github.com/nektro/aquila/pkg/db"
	etc "github.com/nektro/go.etc"
)

func Index(w http.ResponseWriter, r *http.Request) {
	writePageResponse(w, r, "/index.hbs", map[string]interface{}{
		"aquila_version":  etc.Version,
		"latest_packages": fixPackages(db.Package{}.GetLatest(15)),
		"latest_versions": db.Version{}.GetLatest(15),
		"top_starred":     fixPackages(db.Package{}.TopStarred(15)),
	})
}

func Static(page string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		writePageResponse(w, r, "/"+page+".hbs", map[string]interface{}{
			"aquila_version": etc.Version,
		})
	}
}
