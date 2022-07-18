#!/usr/bin/env bash

set -eu

os="$1"
arch="$2"
zigarch=$(zig run tools/os-zigify-arch.zig --main-pkg-path . -- $os $arch)
dir="$(pwd)/images/$zigarch/$os"
before="$dir/stage1.qcow2"
after="$dir/stage2.qcow2"


if [ ! -f $before ]
then
    exit 1
fi

if [ -f $after ]
then
    exit 0
fi

set -x

#
# create qemu disk
qemu-img create -f qcow2 -F qcow2 -b $(basename $before) $after

#
# run qemu disk with iso installer
qemu-kvm \
    -m 2048 \
    -hda $after \
    -net nic \
    -net user \

# TODO automate installer

case "$os" in
    alpine)
        # apk add curl
        # curl -s https://clbin.com/piHwV > /etc/ssh/sshd_config
        # apk add git
        # git clone https://github.com/llvm/llvm-project
        # git clone https://github.com/ziglang/zig
        # mkdir out
        # poweroff
    ;;
    debian)
        # apt install curl
        # curl -s https://clbin.com/piHwV > /etc/ssh/sshd_config
        # apt install git
        # git clone https://github.com/llvm/llvm-project
        # git clone https://github.com/ziglang/zig
        # mkdir out
        # shutdown -h now
    ;;
esac
