ARG BUILDENV_BUILD_DATE \
    OPENSSL_VERSION \
    OPENSSL_SHA256 \
    OPENSSL_BUILDENV_VERSION 

FROM alpine:latest AS buildenv

LABEL maintainer="madnuttah"

ARG OPENSSL_VERSION \
    OPENSSL_SHA256

ENV OPENSSL_VERSION=${OPENSSL_VERSION} \
    OPENSSL_SHA256=${OPENSSL_SHA256}\
    OPENSSL_DOWNLOAD_URL="https://www.openssl.org/source/openssl" \
    OPENSSL_PGP="EFC0A467D613CB83C7ED6D30D894E2CE8B3D79F5"
    
WORKDIR /tmp/src

RUN set -xe; \
  apk --update --no-cache add \
  ca-certificates \
  gnupg \
  curl \
  file && \
  apk --update --no-cache add --virtual .build-deps \
    build-base \
    perl \
    libidn2-dev \
    libevent-dev \
    linux-headers \
    apk-tools && \
    curl -sSL "${OPENSSL_DOWNLOAD_URL}"-"${OPENSSL_VERSION}".tar.gz -o openssl.tar.gz && \
    echo "${OPENSSL_SHA256} ./openssl.tar.gz" | sha256sum -c - && \
    curl -L "${OPENSSL_DOWNLOAD_URL}"-"${OPENSSL_VERSION}".tar.gz.asc -o openssl.tar.gz.asc && \
    GNUPGHOME="$(mktemp -d)" && \
    export GNUPGHOME && \
    gpg --no-tty --keyserver hkps://keys.openpgp.org \
      --recv-keys "${OPENSSL_PGP}" && \
    gpg --batch --verify openssl.tar.gz.asc openssl.tar.gz && \
    tar xzf openssl.tar.gz && \
    cd openssl-"${OPENSSL_VERSION}" && \
    ./Configure \
      no-weak-ssl-ciphers \
      no-apps \
      no-docs \
      no-legacy \
      no-ssl3 \
      no-err \
      no-autoerrinit \
      enable-tfo \
      enable-quic \
      enable-ktls \
      enable-ec_nistp_64_gcc_128 \
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
  pkill -9 gpg-agent && \
  pkill -9 dirmngr && \
  rm -rf \
    /usr/share/man \
    /usr/share/docs \
    /usr/local/openssl/bin \
    /tmp/* \
    /var/tmp/* \
    /var/log/* 
