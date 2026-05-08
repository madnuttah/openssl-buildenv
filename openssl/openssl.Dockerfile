ARG TARGETPLATFORM
ARG TARGETARCH

FROM alpine:latest AS buildenv

ARG TARGETARCH
ARG BUILDENV_BUILD_DATE
ARG OPENSSL_BUILDENV_VERSION
ARG OPENSSL_VERSION
ARG OPENSSL_SHA256

ENV BUILDENV_BUILD_DATE="${BUILDENV_BUILD_DATE}"

LABEL maintainer="madnuttah" \
      build_date="${BUILDENV_BUILD_DATE}" \
      openssl_buildenv_version="${OPENSSL_BUILDENV_VERSION}" \
      openssl_version="${OPENSSL_VERSION}"

ENV PREFIX="/usr/local" \
    PATH="/usr/local/openssl/bin:/usr/local/bin:${PATH}" \
    PKG_CONFIG_PATH="/usr/local/openssl/lib/pkgconfig:/usr/local/lib/pkgconfig"

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

RUN curl -L --fail --no-progress-meter \
      "https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz" \
      -o "openssl-${OPENSSL_VERSION}.tar.gz" && \
    echo "${OPENSSL_SHA256}  openssl-${OPENSSL_VERSION}.tar.gz" | sha256sum -c - && \
    tar -xf "openssl-${OPENSSL_VERSION}.tar.gz" && \
    mv "openssl-${OPENSSL_VERSION}" openssl

WORKDIR /src/openssl

RUN case "$TARGETARCH" in \
      amd64) CONF="linux-x86_64"; EXTRA="enable-ec_nistp_64_gcc_128 enable-ktls enable-asm";; \
      386)   CONF="linux-x86";    EXTRA="enable-asm";; \
      armv7) CONF="linux-armv4";  EXTRA="enable-asm";; \
      arm)   CONF="linux-armv4";  EXTRA="enable-asm";; \
      *) echo "Unsupported arch: $TARGETARCH"; exit 1;; \
    esac && \
    CFLAGS="-O3 -D_FORTIFY_SOURCE=2 -fstack-protector-strong -fstack-clash-protection -fpic -DOPENSSL_NO_HEARTBEATS" \
    LDFLAGS="-Wl,-z,relro,-z,now" \
    ./Configure \
      ${CONF} \
      ${EXTRA} \
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

RUN find /usr/local -type f -name "*.a" -delete && \
    find /usr/local -type f -name "*.la" -delete && \
    apk del .build-deps gettext-dev && \
    rm -rf /src /tmp/* /var/tmp/* /var/log/*
