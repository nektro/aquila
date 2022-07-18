#!/bin/sh

set -eu

# https://www.netbsd.org/
#


os="netbsd"
arch="$1"
version="9.2"

if [ -z "$arch" ]
then
    echo "Must pass an arch value."
    exit
fi

set -x

iso="NetBSD-$version-$arch.iso"
url="https://cdn.netbsd.org/pub/NetBSD/NetBSD-$version/images/$iso"

zigarch=$(zig run tools/os-zigify-arch.zig --main-pkg-path . -- "$os" "$arch")
hdd="images/$zigarch/$os/stage1.qcow2"


#
# ensure we have the iso on disk
mkdir -p iso
wget -P iso --no-clobber --quiet --show-progress $url


if [ ! -f $hdd ]
then
    #
    # create qemu disk
    mkdir -p $(dirname $hdd)
    qemu-img create -f qcow2 $hdd 64G

    #
    # run qemu disk with iso installer
    qemu-kvm \
        -m 2048 \
        -hda $hdd \
        -boot d \
        -cdrom iso/$iso \
        -net nic -net user \

    # TODO automate installer
fi
