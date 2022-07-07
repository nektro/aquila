#!/bin/sh

set -e

# https://www.debian.org/
# https://wiki.debian.org/DebianInstaller/Preseed/EditIso


os="debian"
version="10.10.0"
arch="$1"

if [ -z "$arch" ]
then
    echo "Must pass an arch value."
    exit
fi

set -x

iso="debian-$version-$arch-netinst.iso"
url="https://cdimage.debian.org/mirror/cdimage/archive/$version/$arch/iso-cd/$iso"

zigarch=$(zig run tools/os-zigify-arch.zig --main-pkg-path . -- "$os" "$arch")
hdd="images/$os.$zigarch.qcow2"


#
# ensure we have the iso on disk
mkdir -p iso
wget -P iso --no-clobber --quiet --show-progress $url


if [ ! -f $hdd ]
then
    #
    # create qemu disk
    mkdir -p images
    qemu-img create -f qcow2 $hdd 4G

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
