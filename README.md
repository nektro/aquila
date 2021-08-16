# Aquila
![loc](https://sloc.xyz/github/nektro/aquila)
[![circleci](https://circleci.com/gh/nektro/aquila.svg?style=svg)](https://circleci.com/gh/nektro/aquila)
[![release](https://img.shields.io/github/v/release/nektro/aquila)](https://github.com/nektro/aquila/releases/latest)
[![goreportcard](https://goreportcard.com/badge/github.com/nektro/aquila)](https://goreportcard.com/report/github.com/nektro/aquila)
[![downloads](https://img.shields.io/github/downloads/nektro/aquila/total.svg)](https://github.com/nektro/aquila/releases)
[![docker_pulls](https://img.shields.io/docker/pulls/nektro/aquila)](https://hub.docker.com/r/nektro/aquila)
[![docker_stars](https://img.shields.io/docker/stars/nektro/aquila)](https://hub.docker.com/r/nektro/aquila)

A federated package index and CI system for the Zig programming language built around the [Zigmod](https://github.com/nektro/zigmod) package manager.

## About Zig
- https://ziglang.org/
- https://github.com/ziglang/zig

## Download
- https://github.com/nektro/aquila/releases

## Building from Source
Go
```
$ go build
```

Zig
```
$ zigmod fetch
$ zig build
```

## Built With

### Go Implementation
- Go 1.16
- See [`go.mod`](./go.mod)

### Zig Implementation
- Zig master (at least `0.9.0-dev.796+fcf2ce0ff`)
- See [`zigmod.lock`](./zigmod.lock)

## License
GNU Affero General Public License v3.0
