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
# mount qcow2 to local file system
mkdir -p mnt
sudo qemu-nbd --connect=/dev/nbd0 $after
sudo fdisk /dev/nbd0 -l

case "$os" in
    # TODO auto pick the the biggest drive for target device
    debian)
        # Device      Boot     Start       End   Sectors  Size Id Type
        # /dev/nbd0p1 *         2048 132216831 132214784   63G 83 Linux
        # /dev/nbd0p2      132218878 134215679   1996802  975M  5 Extended
        # /dev/nbd0p5      132218880 134215679   1996800  975M 82 Linux swap / Solaris
        sudo mount --rw /dev/nbd0p1 $(pwd)/mnt/
    ;;
    alpine)
        # Device      Boot   Start       End   Sectors  Size Id Type
        # /dev/nbd0p1 *       2048    206847    204800  100M 83 Linux
        # /dev/nbd0p2       206848   8357887   8151040  3.9G 82 Linux swap / Solaris
        # /dev/nbd0p3      8357888 134217727 125859840   60G 83 Linux
        sudo mount --rw /dev/nbd0p3 $(pwd)/mnt/
    ;;
esac

#
# install files
case "$os" in
    debian|alpine)
        sudo mkdir -p mnt/root/.ssh
        cat docs/etc/sshd_config | sudo tee mnt/etc/ssh/sshd_config > /dev/null
        cat docs/etc/id_rsa.pub | sudo tee mnt/root/.ssh/authorized_keys > /dev/null
        sudo mkdir -p mnt/root/out
        sudo mkdir -p mnt/root/workspace
    ;;
esac

# unmount and disconnect
sudo umount $(pwd)/mnt/
sudo qemu-nbd --disconnect /dev/nbd0
rm -r mnt

#
# start vm now that we have ssh
qemu-kvm -m 20480 -hda $after -net nic -net user,hostfwd=tcp::2222-:22 &
sleep 15

#
# util command
dossh() {
    sshpass -p root ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeychecking=no -p 2222 root@localhost $@
}

#
# run headless commands
case "$os" in
    debian)
        dossh apt install curl
        dossh apt install git
        dossh git clone --progress https://github.com/llvm/llvm-project
        dossh git clone --progress https://github.com/ziglang/zig
        dossh shutdown -h now
    ;;
    alpine)
        dossh apk add curl
        dossh apk add git
        dossh git clone --progress https://github.com/llvm/llvm-project
        dossh git clone --progress https://github.com/ziglang/zig
        dossh poweroff
    ;;
esac
