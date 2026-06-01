# OpenSSL & OpenSSL+QUIC Build Environment

[![Current OpenSSL release](https://img.shields.io/github/v/tag/openssl/openssl?label=Current%20OpenSSL%20release&style=flat-square)](https://github.com/openssl/openssl/tags)
[![OpenSSL buildenv](https://img.shields.io/github/v/release/madnuttah/openssl-buildenv?label=madnuttah/openssl-buildenv%20release&style=flat-square)](https://github.com/madnuttah/openssl-buildenv/releases)

[![Security Analysis (zizmor)](https://github.com/madnuttah/openssl-buildenv/actions/workflows/cd-gh-action-zizmor-scan.yaml/badge.svg)](https://github.com/madnuttah/openssl-buildenv/actions/workflows/cd-gh-action-zizmor-scan.yaml)
[![StepSecurity Harden Runner](https://img.shields.io/badge/Secured%20by-StepSecurity-blue?style=flat-square)](https://github.com/step-security/harden-runner)

This repository provides a reproducible, multi‑architecture build environment for:

- OpenSSL
- OpenSSL with QUIC support (ngtcp2, nghttp3, sfparse)

The build environments are designed for deterministic cryptographic behavior, stable toolchain generation, and consistent results across architectures. They are used by `madnuttah/unbound-docker` to ensure reliable TLS and QUIC support.

The project includes hardened CI pipelines, static analysis, and dependency pinning to maintain a trustworthy and auditable build process.

---

## Technical Overview

### Build Environments

Two independent build environments are provided:

#### OpenSSL Buildenv
A minimal environment that compiles OpenSSL with:

- architecture‑specific tuning
- hardened compiler flags
- shared libraries only
- no legacy algorithms
- no documentation or apps
- stripped binaries for reduced size

This environment is intended for systems that require a clean, optimized OpenSSL toolchain without QUIC dependencies.

#### OpenSSL+QUIC Buildenv
A full QUIC‑enabled toolchain that builds:

- OpenSSL
- sfparse
- nghttp3
- ngtcp2 (including crypto backend)

This environment is isolated from the default build due to its larger dependency graph and higher maintenance cost. It is intended for QUIC‑capable applications and testing.

---

## CI/CD and Security

The repository uses a hardened CI pipeline with the following components:

### Static and Workflow Analysis
- CodeQL for semantic vulnerability detection
- zizmor for GitHub Actions workflow security analysis
- ShellCheck and Hadolint for linting shell scripts and Dockerfiles

### Runner Hardening
- StepSecurity Harden Runner to restrict outbound traffic and enforce secure defaults

### Build Integrity
- Pinned dependency versions
- Immutable base images
- Reproducible build flags
- Stripped binaries and removed static archives
- Architecture‑specific build logic

### Release Automation
- Automatic tagging and GitHub Releases
- Version extraction from tracked files
- Optional GPG signing
- Generated release notes including upstream component versions

---

## Usage

These images are intended to be used as build‑time toolchains. Example:

```bash
docker run --rm -it madnuttah/openssl-buildenv:latest openssl version
```

They can also be used in multi‑stage Docker builds to provide a consistent OpenSSL or QUIC‑enabled toolchain.

---

## Acknowledgements

- Alpine Linux
- Docker
- OpenSSL
- ngtcp2
- nghttp3
- sfparse

---

## Licenses

### Project License
All code in this repository is released under the MIT License.  
See the `LICENSE` file for details.

### Upstream Licenses
- Docker: Apache 2.0
- OpenSSL: Apache-style license
- ngtcp2 / nghttp3 / sfparse: MIT

