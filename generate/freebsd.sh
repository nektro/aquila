#!/bin/sh

set -e

# https://www.freebsd.org/
#


os="freebsd"
arch="$1"
version="13.0"

if [ -z "$arch" ]
then
    echo "Must pass an arch value."
    exit
fi

set -x

iso="FreeBSD-$version-RELEASE-$arch-bootonly.iso"
url="https://download.freebsd.org/ftp/releases/ISO-IMAGES/$version/$iso"

zigarch=$(zig run tools/os-zigify-arch.zig -- "$os" "$arch")
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

    # TODO automate installer
fi
