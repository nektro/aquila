package global

import (
	oauth2 "github.com/nektro/go.oauth2"
)

type ConfigT struct {
	Clients   []oauth2.AppConf  `json:"clients"`
	Providers []oauth2.Provider `json:"providers"`
}

var (
	Config = &ConfigT{}
	Domain string
)
