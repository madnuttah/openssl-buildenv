# `OpenSSL & OpenSSL+QUIC Build Environment`

[![Current OpenSSL release](https://img.shields.io/github/v/tag/openssl/openssl?label=Current%20OpenSSL%20release&style=flat-square)](https://github.com/openssl/openssl/tags)
[![OpenSSL buildenv](https://img.shields.io/github/v/release/madnuttah/openssl-buildenv?label=madnuttah/openssl-buildenv%20release&style=flat-square)](https://github.com/madnuttah/openssl-buildenv/releases)

[![GitHub Actions Security Analysis with zizmor](https://github.com/madnuttah/openssl-buildenv/actions/workflows/cd-gh-action-zizmor-scan.yaml/badge.svg)](https://github.com/madnuttah/openssl-buildenv/actions/workflows/cd-gh-action-zizmor-scan.yaml)

This repository provides a dedicated and optimized build environment for compiling native OpenSSL and OpenSSL+QUIC toolchains.  

It is designed for projects that require consistent cryptographic behavior, reproducible builds, and architecture‑specific performance tuning. 

The environment is used by [`madnuttah/unbound-docker`](https://github.com/madnuttah/unbound-docker/) to ensure deterministic TLS and QUIC support across all supported platforms.

The build pipelines run on hardened infrastructure, use continuous dependency maintenance, and include automated security analysis to keep the toolchain trustworthy and up to date.

## Acknowledgements

- [Alpine Linux](https://www.alpinelinux.org/)
- [Docker](https://www.docker.com/)
- [OpenSSL](https://www.openssl.org/)

## Licenses

### License

Unless otherwise specified, all code is released under the MIT license.  
See the [`LICENSE`](https://github.com/madnuttah/openssl-buildenv/blob/main/LICENSE) for details.

### Licenses for other components

- Docker: [Apache 2.0](https://github.com/docker/docker/blob/master/LICENSE)
- OpenSSL: [Apache-style license](https://www.openssl.org/source/license.html)
