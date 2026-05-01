FROM alpine:latest AS openssl

LABEL maintainer="madnuttah"

WORKDIR /tmp/src

RUN set -xe; \
  apk add --no-cache \
    ca-certificates \
    jq \
    curl && \
  export OPENSSL_VERSION=$(curl -s https://api.github.com/repos/quictls/openssl/releases/latest | jq -r .tag_name); \
  echo "Using OpenSSL QUIC version: ${OPENSSL_VERSION}" && \
  apk add --no-cache --virtual .build-deps \
    build-base \
    perl \
    libidn2-dev \
    git \
    curl \
    linux-headers && \
  curl -sSL https://github.com/quictls/openssl/archive/refs/tags/${OPENSSL_VERSION}.tar.gz -o openssl.tar.gz && \
  tar -xzf openssl.tar.gz && \
  rm openssl.tar.gz && \
  cd openssl-${OPENSSL_VERSION} && \
  ./config \
    linux-generic32 \
    enable-tls1_3 \
    no-shared \
    no-pinshared \
    threads \
    no-weak-ssl-ciphers \
    no-ssl3 \
    no-err \
    no-autoerrinit \
    -fPIC \
    -DOPENSSL_NO_HEARTBEATS \
    -fstack-protector-strong \
    -fstack-clash-protection \
    --prefix=/usr/local/openssl \
    --openssldir=/usr/local/openssl \
    --libdir=/usr/local/openssl/lib && \
  make && \
  make install_sw && \
  apk del --no-cache .build-deps && \
  cd / && \
  rm -rf /tmp/src


FROM alpine:latest AS buildenv

WORKDIR /tmp/src

COPY --from=openssl /usr/local/openssl/ \
  /usr/local/openssl/

RUN set -xe; \
  apk add --no-cache \
    ca-certificates \
    jq \
    curl && \
  export NGTCP2_VERSION=$(curl -s https://api.github.com/repos/ngtcp2/ngtcp2/releases/latest | jq -r .tag_name | sed 's/^v//'); \
  echo "Using ngtcp2 version: ${NGTCP2_VERSION}" && \
  apk add --no-cache --virtual .build-deps \
    build-base \
    perl \
    curl \
    automake \
    autoconf \
    libtool \
    libidn2-dev \
    linux-headers && \
  curl -sSL https://github.com/ngtcp2/ngtcp2/releases/download/v${NGTCP2_VERSION}/ngtcp2-${NGTCP2_VERSION}.tar.gz -o ngtcp2.tar.gz && \
  tar -xzf ngtcp2.tar.gz && \
  rm ngtcp2.tar.gz && \
  cd ngtcp2-"${NGTCP2_VERSION}" && \
  autoreconf -i && \
  ./configure \
    PKG_CONFIG_PATH=/usr/local/openssl/lib/pkgconfig \
    LDFLAGS="-Wl,-rpath,/usr/local/openssl/lib" \
    --prefix=/usr/local/ngtcp2 && \
  make && \
  make install && \
  apk del --no-cache .build-deps && \
  cd / && \
  rm -rf \
    /usr/share/man \
    /usr/share/docs \
    /tmp/* \
    /var/tmp/* \
    /var/log/*
