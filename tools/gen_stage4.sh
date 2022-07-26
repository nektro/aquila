#!/bin/sh

set -eu

os="$1"
arch="$2"
zigarch=$(zig run tools/os-zigify-arch.zig --main-pkg-path . -- $os $arch)
dir="$(pwd)/images/$zigarch/$os"
before="$dir/stage3.qcow2"
after="$dir/stage4.qcow2"


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
# start system
qemu-kvm -m 20480 -hda $after -net nic -net user,hostfwd=tcp::2222-:22 &
sleep 15

#
# util command
dossh() {
    sshpass -p root ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeychecking=no -p 2222 root@localhost $@
}

#
# build zig
case "$os" in
    debian)
        PROJDIR="/root/zig"
        dossh cd ${PROJDIR} '&&' git fetch
        dossh cd ${PROJDIR} '&&' git pull
        dossh cd ${PROJDIR} '&&' mkdir -pv build
        dossh cd ${PROJDIR}/build '&&' cmake .. -DCMAKE_INSTALL_PREFIX='/root/out'
        dossh cd ${PROJDIR}/build '&&' make
        dossh shutdown -h now
    ;;
esac
