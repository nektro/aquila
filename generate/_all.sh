#!/bin/sh

set -e
set -x

# Meta script for building all architectures of an OS

os="$1"

for arc in $(zig run tools/os-list-arches.zig -- "$os")
do
    ./generate/$os.sh $arc
done
