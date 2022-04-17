# Supported Platforms

Support of a given platform is indicated by a tier system. The tiers are as follows:

> Note: this list is incomplete and being developed in tandem with the rest of the server currently.

> Note: for the full list of Zig supported architectures see https://ziglang.org/documentation/master/std/#std;Target.Cpu.Arch

> Note: for the full list of QEMU supported architectures see https://pkgs.alpinelinux.org/packages?name=qemu-system-*&branch=edge&arch=x86_64

0. The os/arch combo is supported in some official capacity by upstream and a potential candidate.

|              | Version | x86_64 | arm64 | x86 | arm | riscv64 | ppc64el | mips64el | sparcv9 | s390x |
|--------------|---------|--------|-------|-----|-----|---------|---------|----------|---------|-------|
| linux/alpine | 3.15.0  | 0      | 0     | 0   | 0   |         | 0       |          |         | 0     |
| linux/debian | 10.10.0 | 0      | 0     | 0   | 0   |         | 0       | 0        |         | 0     |
| freebsd      | 13.0    | 0      | 0     | 0   |     | 0       | 0       |          |         |       |
| netbsd       | 9.2     | 0      | 0     | 0   | 0   |         |         | 0        | 0       |       |
| openbsd      | 7.0     | 0      | 0     | 0   | 0   | 0       |         |          | 0       |       |
| dragonflybsd | 6.0.1   | 0      |       |     |     |         |         |          |         |       |
| linux/nixos  | 21.05   | 0      |       | 0   |     |         |         |          |         |       |
| plan9/9front | 8593    | 0      |       | 0   |     |         |         |          |         |       |

<!--
| windows      |         | 0      | 0     | 0   | 0   |
| macos        |         | 0      | 0     |
| solaris   `^`|         |
| illumos   `^`|         |
| haiku     `^`|         |
| fuscia    `^`|         |
| serenity  `^`|         |
| essence   `^`|         |
| android   `^`|         |
-->


<!-- https://docs.drone.io/pipeline/exec/syntax/platform/#supported-platforms -->
<!-- https://man.sr.ht/builds.sr.ht/compatibility.md -->
<!-- https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#choosing-github-hosted-runners -->
<!-- https://docs.gitlab.com/runner/install/ -->
