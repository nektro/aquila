#!/usr/bin/env bash

set -e

version="r$(./release_num.sh)"
rev=$(git log --format=%h -1)

target=$1

# TODO error if $target is empty

echo "$version.$rev $target"
zig build -Dtarget=$target -Duse-full-name -Dversion=$version --prefix . -Drelease
