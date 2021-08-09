#!/bin/sh

set -x
set -e

apk add --no-cache wget
wget https://github.com/nektro/zigmod/releases/download/v68/zigmod-$(uname -m)-linux -O zigmod
chmod +x ./zigmod

apk add --no-cache git libc-dev musl-dev build-base gcc ca-certificates
export VCS_REF="v${BUILD_NUM}-docker"
echo $VCS_REF
go get -v .
go get -v github.com/rakyll/statik
$GOPATH/bin/statik -src="./www/"
CGO_ENABLED=1 go build -ldflags "-s -w -X main.Version=$VCS_REF" .
