ARG BUILDENV_BUILD_DATE \
    QUICTLS_VERSION_UPSTREAM \
    NGTCP2_VERSION

FROM alpine:latest AS buildenv

LABEL maintainer="madnuttah"

ARG QUICTLS_VERSION_UPSTREAM \
    NGTCP2_VERSION

ENV QUICTLS_VERSION=${QUICTLS_VERSION_UPSTREAM} \
    NGTCP2_VERSION=${NGTCP2_VERSION} \
    QUICTLS_PGP="8657ABB260F056B1E5190839D9C4D26D0E604491" \
    QUICTLS_URL="https://github.com/quictls/quictls/archive/refs/tags" \
    NGTCP2_URL="https://github.com/ngtcp2/ngtcp2/releases/download"

WORKDIR /tmp/src

RUN set -xe; \
  apk --update --no-cache add \
    ca-certificates \
    gnupg \
    curl \
    file \
    jq && \
  apk --update --no-cache add --virtual .build-deps \
    build-base \
    perl \
    libidn2-dev \
    libevent-dev \
    linux-headers \
    apk-tools && \
  curl -sSL "${QUICTLS_URL}/${QUICTLS_VERSION}.tar.gz" -o quictls.tar.gz && \
  curl -sSL "${QUICTLS_URL}/${QUICTLS_VERSION}.tar.gz.asc" -o quictls.tar.gz.asc && \
  GNUPGHOME="$(mktemp -d)" && export GNUPGHOME && \
  gpg --no-tty --keyserver hkps://keys.openpgp.org --recv-keys "${QUICTLS_PGP}" && \
  gpg --batch --verify quictls.tar.gz.asc quictls.tar.gz && \
  tar xzf quictls.tar.gz && \
  cd quictls-* && \
  ./Configure \
      linux-generic32 \
      enable-quic \
      enable-ktls \
      threads \
      no-shared \
      no-pic \
      no-apps \
      no-docs \
      no-tests \
      no-ssl3 \
      no-weak-ssl-ciphers \
      no-legacy \
      -fPIC \
      -DOPENSSL_NO_HEARTBEATS \
      --prefix=/usr/local/openssl \
      --openssldir=/usr/local/openssl \
      --libdir=/usr/local/openssl/lib && \
  make -j$(nproc) && \
  make install_sw && \
  curl -sSL "${NGTCP2_URL}/v${NGTCP2_VERSION}/ngtcp2-${NGTCP2_VERSION}.tar.gz" -o ngtcp2.tar.gz && \
  tar xzf ngtcp2.tar.gz && \
  cd ngtcp2-${NGTCP2_VERSION} && \
  ./configure \
      --prefix=/usr/local/ngtcp2 \
      --enable-lib-only \
      --with-openssl=/usr/local/openssl && \
  make -j$(nproc) && \
  make install && \
  apk del --no-cache .build-deps && \
  pkill -9 gpg-agent || true && \
  pkill -9 dirmngr || true && \
  rm -rf \
    /usr/share/man \
    /usr/share/docs \
    /usr/local/openssl/bin \
    /tmp/* \
    /var/tmp/* \
    /var/log/*
