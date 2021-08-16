id: ehmrk2r56odz4np1cy1oibtqv9q03bxtyz36twutgyti0oj8
name: aquila
license: AGPL-3.0
description: A federated package index and CI system for the Zig programming language built around the Zigmod package manager.
bin: True
provides: ["aquila"]
root_files:
  - www
dev_dependencies:
  - src: git https://github.com/nektro/apple_pie
  - src: git https://github.com/nektro/zig-pek
