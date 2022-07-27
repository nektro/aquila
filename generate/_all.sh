#!/bin/sh

set -eu
set -x

# Meta script for building all architectures of an OS

os="$1"
arch="$2"

./generate/$os.sh $arch
./tools/gen_stage2.sh $os $arch
./tools/gen_stage3.sh $os $arch
./tools/gen_stage4.sh $os $arch
