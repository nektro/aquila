#!/bin/sh

set -eu

version="r$(./release_num.sh)"
rev=$(git log --format=%h -1)

targets="
x86_64-linux
aarch64-linux
riscv64-linux
powerpc64-linux
"

for item in $targets
do
    ./build_release.sh $item
done
