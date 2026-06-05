ARG TARGETPLATFORM
ARG TARGETARCH

FROM alpine:3.23.4@sha256:5b10f432ef3da1b8d4c7eb6c487f2f5a8f096bc91145e68878dd4a5019afde11 AS buildenv

ARG TARGETARCH
ARG BUILDENV_BUILD_DATE
ARG OPENSSL_VERSION
ARG OPENSSL_SHA256

ARG TARGETPLATFORM
ARG TARGETARCH

ENV BUILDENV_BUILD_DATE="${BUILDENV_BUILD_DATE}"

LABEL maintainer="madnuttah" \
      build_date="${BUILDENV_BUILD_DATE}" \
      openssl_version="${OPENSSL_VERSION}"

ENV PREFIX="/usr/local" \
    PATH="/usr/local/openssl/bin:/usr/local/bin:${PATH}" \
    PKG_CONFIG_PATH="/usr/local/openssl/lib/pkgconfig:/usr/local/lib/pkgconfig"

# hadolint ignore=DL3018
RUN set -xe; \
  apk --update --no-cache add \
    ca-certificates \
    curl \
    bash \
    perl \
    perl-utils \
    python3 \
    jq \
    git \
    gnupg \
    libev-dev \
    pkgconf \
    gettext-dev \
    linux-headers && \
  apk --update --no-cache add --virtual .build-deps \
    build-base \
    autoconf \
    automake \
    libtool \
    pkgconfig \
    cmake && \
  update-ca-certificates

WORKDIR /src

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN curl -L --fail --no-progress-meter \
      "https://github.com/openssl/openssl/releases/download/${OPENSSL_VERSION}/${OPENSSL_VERSION}.tar.gz" \
      -o "${OPENSSL_VERSION}.tar.gz" && \
    echo "${OPENSSL_SHA256}  ${OPENSSL_VERSION}.tar.gz" | sha256sum -c - && \
    tar -xf "${OPENSSL_VERSION}.tar.gz" && \
    mv "${OPENSSL_VERSION}" openssl

WORKDIR /src/openssl

# hadolint ignore=DL3018
RUN case "$TARGETARCH" in \
      amd64)   CONF="linux-x86_64";    EXTRA="enable-ec_nistp_64_gcc_128 enable-ktls enable-asm";; \
      arm64)   CONF="linux-aarch64";   EXTRA="enable-ec_nistp_64_gcc_128 enable-ktls enable-asm";; \
      386)     CONF="linux-x86";       EXTRA="enable-asm";; \
      armv6)   CONF="linux-armv4";     EXTRA="enable-asm";; \
      armv7)   CONF="linux-armv4";     EXTRA="enable-asm";; \
      ppc64le) CONF="linux-ppc64le";   EXTRA="enable-asm";; \
      s390x)   CONF="linux64-s390x";   EXTRA="enable-asm";; \
      riscv64) CONF="linux64-riscv64"; EXTRA="enable-asm";; \
      *) echo "Unsupported arch: $TARGETARCH"; exit 1;; \
    esac && \
    CFLAGS="-O3 -D_FORTIFY_SOURCE=2 -fstack-protector-strong -fstack-clash-protection -fpic -DOPENSSL_NO_HEARTBEATS" \
    LDFLAGS="-Wl,-z,relro,-z,now" \
    ./Configure \
      "${CONF}" \
      ${EXTRA:+$EXTRA} \
      no-weak-ssl-ciphers \
      no-apps \
      no-docs \
      shared \
      no-legacy \
      no-err \
      no-autoerrinit \
      enable-tfo \
      --prefix=/usr/local/openssl \
      --openssldir=/usr/local/openssl \
      --libdir=/usr/local/openssl/lib && \
    make -j"$(nproc)" && \
    make install_sw

RUN strip --strip-unneeded /usr/local/lib/*.so* || true && \
    strip --strip-unneeded /usr/local/openssl/lib/*.so* || true && \
    strip --strip-all /usr/local/bin/* || true && \
    strip --strip-all /usr/local/openssl/bin/* || true && \
    rm -f /usr/local/lib/*.a /usr/local/lib/*.la && \
    rm -f /usr/local/openssl/lib/*.a /usr/local/openssl/lib/*.la && \
    rm -rf /usr/local/openssl/ssl/man \
           /usr/local/openssl/ssl/misc \
           /usr/local/openssl/ssl/certs && \
    rm -rf /src /tmp/* /var/tmp/* /var/log/*

FROM alpine:3.23.4@sha256:5b10f432ef3da1b8d4c7eb6c487f2f5a8f096bc91145e68878dd4a5019afde11 AS final

COPY --from=buildenv /usr/local /usr/local

# hadolint ignore=DL3018
RUN apk --update --no-cache add ca-certificates && \
    update-ca-certificates