<p align="center">
    <img src="https://repository-images.githubusercontent.com/440215882/b79c7ae3-c3d4-4a6a-a1d7-d27fa626754b" alt="Logo">
</p>

# OpenSSL Build Environment

[![CD Check OpenSSL release](https://img.shields.io/github/actions/workflow/status/madnuttah/openssl-buildenv/cd-check-openssl-release.yaml?branch=main&label=CD%OpenSSL%20Release&style=flat-square)](https://github.com/madnuttah/openssl/blob/main/.github/workflows/cd-check-openssl-release.yaml)
[![CD Build OpenSSL Buildenv](https://img.shields.io/github/actions/workflow/status/madnuttah/openssl-buildenv/cd-build-openssl-buildenv.yaml?branch=main&label=CD%20madnuttah/openssl-buildenv%20build%20status&style=flat-square)](https://github.com/madnuttah/openssl/blob/main/.github/workflows/cd-build-openssl-buildenv.yaml)
[![Manual Build OpenSSL Buildenv](https://img.shields.io/github/actions/workflow/status/madnuttah/openssl-buildenv/manually-build-openssl-buildenv.yaml?branch=main&label=Manually%20madnuttah/openssl-buildenv%20build%20status&style=flat-square)](https://github.com/madnuttah/openssl-buildenv/blob/main/.github/workflows/manually-build-openssl-buildenv.yaml)

[![GitHub version](https://img.shields.io/github/v/release/madnuttah/openssl-buildenv?include_prereleases&label=madnuttah/openssl-buildenv%20release&style=flat-square)](https://github.com/madnuttah/openssl-buildenv/releases)

**This is the optimized OpenSSL build environment for [`madnuttah/unbound-docker`](https://github.com/madnuttah/unbound-docker/).**

It doesn't contain any OpenSSL binaries, only libraries.
 
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
