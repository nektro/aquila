#!/bin/sh

set -eu

os="$1"
arch="$2"
zigarch=$(zig run tools/os-zigify-arch.zig --main-pkg-path . -- $os $arch)
dir="$(pwd)/images/$zigarch/$os"
before="$dir/stage2.qcow2"
after="$dir/stage3.qcow2"


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
# build llvm
case "$os" in
    debian)
        PROJDIR="/root/llvm-project"
        dossh apt install g++ cmake make python3
        dossh cd ${PROJDIR} '&&' git fetch
        dossh cd ${PROJDIR} '&&' git checkout release/14.x
        dossh cd ${PROJDIR} '&&' git pull
        dossh cd ${PROJDIR} '&&' git describe --tags
        dossh cd ${PROJDIR} '&&' mkdir -pv build
        dossh cd ${PROJDIR}/build '&&' cmake ../llvm -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_ASSERTIONS=ON -DCMAKE_PREFIX_PATH="/root/out" -DCMAKE_INSTALL_PREFIX="/root/out" "'-DLLVM_ENABLE_PROJECTS=lld;clang'" -DLLVM_BUILD_LLVM_DYLIB=ON -DLLVM_LINK_LLVM_DYLIB=ON -DLLVM_ENABLE_LTO=OFF -DLLVM_ENABLE_BINDINGS=OFF -DLLVM_ENABLE_LIBXML2=OFF -DLLVM_ENABLE_OCAMLDOC=OFF -DLLVM_ENABLE_Z3_SOLVER=OFF -DLLVM_INCLUDE_TESTS=OFF -DLLVM_INCLUDE_EXAMPLES=OFF -DLLVM_INCLUDE_BENCHMARKS=OFF -DLLVM_INCLUDE_DOCS=OFF -DLLVM_INCLUDE_GO_TESTS=OFF -DCLANG_BUILD_TOOLS=OFF -DCLANG_INCLUDE_DOCS=OFF
        dossh cd ${PROJDIR}/build '&&' make install
        dossh shutdown -h now
    ;;
esac
