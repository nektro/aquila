#!/bin/sh

set -e

# https://alpinelinux.org/
#


os="alpine"
arch="$1"
version="3.15.0"

if [ -z "$arch" ]
then
    echo "Must pass an arch value."
    exit
fi

set -x

iso="alpine-virt-$version-$arch.iso"
shortv=$(echo $version | cut -d . -f -2)
url="https://dl-cdn.alpinelinux.org/alpine/v$shortv/releases/$arch/$iso"

zigarch=$(zig run tools/os-zigify-arch.zig -- $os $arch)
hdd="images/$os.$zigarch.qcow2"


#
# ensure we have the iso on disk
mkdir -p iso
wget -P iso --no-clobber --quiet --show-progress $url


if [ ! -f $hdd ]
then
    #
    # create qemu 32 GB disk
    mkdir -p images
    qemu-img create -f qcow2 $hdd 32G

    #
    # run qemu disk with iso installer
    qemu-system-$zigarch \
        -m 2048 \
        -hda $hdd \
        -boot d \
        -cdrom iso/$iso \
        -net nic -net user \
        -nographic \

    # TODO automate installer
fi
