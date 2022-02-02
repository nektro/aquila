id: ehmrk2r56odz4np1cy1oibtqv9q03bxtyz36twutgyti0oj8
name: aquila
license: AGPL-3.0
description: A federated package index and CI system for the Zig programming language built around the Zigmod package manager.
min_zig_version: 0.10.0-dev.513+029844210
bin: True
provides: ["aquila"]
root_files:
  - www
root_dependencies:
  - src: git https://github.com/nektro/iguanaTLS

  - src: git https://github.com/Luukdegram/apple_pie
  - src: git https://github.com/nektro/zig-pek
  - src: git https://github.com/nektro/zig-zorm
  - src: git https://github.com/nektro/zig-extras
  - src: git https://github.com/leroycep/zig-jwt
  - src: git https://github.com/nektro/zig-oauth2
  - src: git https://github.com/nektro/zig-flag
  - src: git https://github.com/nektro/zig-json
  - src: git https://github.com/nektro/zig-ulid
  - src: git https://github.com/nektro/zig-time
  - src: git https://github.com/truemedian/zfetch
  - src: git https://github.com/nektro/zigmod
  - src: git https://github.com/nektro/zig-git
