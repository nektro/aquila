#!/usr/bin/env bash

set -x
set -e

# download Zig

os="linux"
arch="x86_64"
version="$1"

dir="zig-$os-$arch-$version"
file="$dir.tar.xz"

cd /

if [[ $1 == *"dev"* ]]; then
    wget https://ziglang.org/builds/$file
else
    wget https://ziglang.org/download/$version/$file
fi

tar -xf $file
ln -s /$dir/zig /usr/local/bin

# download Zigmod

curl -s 'https://api.github.com/repos/nektro/zigmod/releases' \
    | jq -r '.[0].assets[].browser_download_url' \
    | grep $(uname -m) \
    | grep -i $(uname -s) \
    | wget -i - -O /usr/local/bin/zigmod

chmod +x /usr/local/bin/zigmod
