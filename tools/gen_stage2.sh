#!/bin/sh

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

if [ ! -f $after ]
then
    #
    # create qemu disk
    qemu-img create -f qcow2 -F qcow2 -b $(basename $before) $after
fi

set -x

#
# run qemu disk with iso installer
qemu-kvm -m 20480 -hda $after -net nic -net user

# TODO automate installer
# TODO code/cli add sshd_config
# TODO code/cli add id_rsa.pub
# TODO code ssh run rest of commands

case "$os" in
    debian)
        # apt install curl
        # mkdir .ssh
        # curl -s https://clbin.com/sSR2s > /etc/ssh/sshd_config
        # curl -s https://clbin.com/6LSMP > /root/.ssh/authorized_keys
        # apt install git
        # git clone https://github.com/llvm/llvm-project
        # git clone https://github.com/ziglang/zig
        # mkdir out
        # mkdir workspace
        # shutdown -h now
    ;;
    alpine)
        # apk add curl
        # mkdir .ssh
        # curl -s https://clbin.com/sSR2s > /etc/ssh/sshd_config
        # curl -s https://clbin.com/6LSMP > /root/.ssh/authorized_keys
        # apk add git
        # git clone https://github.com/llvm/llvm-project
        # git clone https://github.com/ziglang/zig
        # mkdir out
        # mkdir workspace
        # poweroff
    ;;
    freebsd)
        # pkg install curl
        # mkdir .ssh
        # curl -s https://clbin.com/sSR2s > /etc/ssh/sshd_config
        # curl -s https://clbin.com/6LSMP > /root/.ssh/authorized_keys
        # pkg install git
        # git clone https://github.com/llvm/llvm-project
        # git clone https://github.com/ziglang/zig
        # mkdir out
        # mkdir workspace
        # shutdown -p now
    ;;
esac
