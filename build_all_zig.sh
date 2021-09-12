#!/usr/bin/env bash

set -e

version="r$(./release_num.sh)"
rev=$(git log --format=%h -1)

targets="
x86_64-linux-musl
"

for item in $targets
do
    echo "$version.$rev $item"
    zig build -Dtarget=$item -Duse-full-name -Dversion=$version.$rev --prefix .
    echo
done
