#!/bin/sh

set -eu
set -x

# Meta script for building all architectures of an OS

os="$1"

# cc https://github.com/ziglang/zig/issues/10754
for arc in $(zig run tools/os-list-arches.zig --main-pkg-path . -- "$os")
do
    ./generate/$os.sh $arc
done
