#!/usr/bin/env bash

build_template() {
    export CGO_ENABLED=1
    export GOOS=$1
    export GOARCH=$2
    export GOARM=7
    ext=$3
    date=$(date +'%Y%m%d')
    version=${CIRCLE_BUILD_NUM-$date}
    tag=v$version
    echo $tag-$GOOS-$GOARCH
    go build -ldflags="-s -w -X main.Version=$tag" -o ./bin/aquila-$tag-$GOOS-$GOARCH$ext
}

go get -v github.com/rakyll/statik
$GOPATH/bin/statik -src="./www/" -f

build_template linux amd64
