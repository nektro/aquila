# Supported Platforms

Support of a given platform is indicated by a tier system. The tiers are as follows:

> Note: this list is incomplete and being developed in tandem with the rest of the server currently.

> Note: for the full list of Zig supported architectures see https://ziglang.org/documentation/master/std/#std;Target.Cpu.Arch

> Note: for the full list of QEMU supported architectures see https://pkgs.alpinelinux.org/packages?name=qemu-system-*&branch=edge&arch=x86_64

> Note: while some functionality listed below might work, then number is only updated once verified.

0. The os/arch combo is supported in some official capacity by upstream and a potential candidate.
1. A script exists in [`generate/`](../../generate) that can download and run the OS' installer; the process is documented in [bootstrap_images.md](bootstrap_images.md).
2. [`tools/gen_stage2.sh`](../../tools/gen_stage2.sh) can run the generated stage 1 `.qcow2` image; contains instructions on enabling ssh, and dowloading LLVM + Zig.
3. [`tools/gen_stage3.sh`](../../tools/gen_stage3.sh) can run the generated stage 2 `.qcow2` image; headlessly boots it and builds LLVM from source then exits.
4. [`tools/gen_stage4.sh`](../../tools/gen_stage4.sh) can run the generated stage 3 `.qcow2` image; headlessly boots it and builds Zig from source then exits.

|              | Version | x86_64 | aarch64 |
|--------------|---------|--------|---------|
| linux/debian | 10.10.0 | 4      | 0       |
| linux/alpine | 3.15.0  | 2      | 0       |
| freebsd      | 13.0    | 2      | 0       |
| netbsd       | 9.2     | 1      | 0       |


<!-- https://docs.drone.io/pipeline/exec/syntax/platform/#supported-platforms -->
<!-- https://man.sr.ht/builds.sr.ht/compatibility.md -->
<!-- https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#choosing-github-hosted-runners -->
<!-- https://docs.gitlab.com/runner/install/ -->
