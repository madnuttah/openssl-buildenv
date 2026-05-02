ARG BUILDENV_BUILD_DATE \
    OPENSSL_VERSION \
    OPENSSL_SHA256 \
    OPENSSL_BUILDENV_VERSION

FROM alpine:latest AS openssl

LABEL maintainer="madnuttah"

ARG OPENSSL_VERSION \
    OPENSSL_SHA256

ENV OPENSSL_VERSION=${OPENSSL_VERSION} \
    OPENSSL_SHA256=${OPENSSL_SHA256} \
    OPENSSL_DOWNLOAD_URL="https://github.com/openssl/openssl/releases/download" \
    OPENSSL_PGP="BA5473A2B0587B07FB27CF2D216094DFD0CB81EF"

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
  curl -sSL "${OPENSSL_DOWNLOAD_URL}/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz" -o openssl.tar.gz && \
  echo "${OPENSSL_SHA256}  openssl.tar.gz" | sha256sum -c - && \
  curl -sSL "${OPENSSL_DOWNLOAD_URL}/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz.asc" -o openssl.tar.gz.asc && \
  GNUPGHOME="$(mktemp -d)" && \
  export GNUPGHOME && \
  gpg --no-tty --keyserver hkps://keys.openpgp.org --recv-keys "${OPENSSL_PGP}" && \
  gpg --batch --verify openssl.tar.gz.asc openssl.tar.gz && \
  tar xzf openssl.tar.gz && \
  cd openssl-"${OPENSSL_VERSION}" && \
  ./Configure \
      linux-generic32 \
      -m32 \
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
      -fPIC \
      -DOPENSSL_NO_HEARTBEATS \
      -fstack-protector-strong \
      -fstack-clash-protection \
      --prefix=/usr/local/openssl \
      --openssldir=/usr/local/openssl \
      --libdir=/usr/local/openssl/lib && \
  make -j"$(nproc)" && \
  make install_sw && \
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


FROM alpine:latest AS ngtcp2

LABEL maintainer="madnuttah"

ARG NGTCP2_VERSION \
    NGTCP2_SHA256 \
    NGHTTP3_VERSION \
    NGHTTP3_SHA256

ENV NGTCP2_VERSION=${NGTCP2_VERSION} \
    NGTCP2_SHA256=${NGTCP2_SHA256} \
    NGHTTP3_VERSION=${NGHTTP3_VERSION} \
    NGHTTP3_SHA256=${NGHTTP3_SHA256} \
    NGTCP2_URL="https://github.com/ngtcp2/ngtcp2/releases/download" \
    NGHTTP3_URL="https://github.com/ngtcp2/nghttp3/releases/download"

WORKDIR /tmp/src

COPY --from=openssl /usr/local/openssl/ /usr/local/openssl/

ENV PKG_CONFIG_PATH=/usr/local/openssl/lib/pkgconfig \
    LD_LIBRARY_PATH=/usr/local/openssl/lib

RUN set -xe; \
  apk --update --no-cache add \
    ca-certificates \
    curl \
    file && \
  apk --update --no-cache add --virtual .build-deps \
    build-base \
    autoconf \
    automake \
    libtool \
    linux-headers \
    perl

RUN curl -sSL "${NGHTTP3_URL}/v${NGHTTP3_VERSION}/nghttp3-${NGHTTP3_VERSION}.tar.gz" -o nghttp3.tar.gz && \
    echo "${NGHTTP3_SHA256}  nghttp3.tar.gz" | sha256sum -c - && \
    tar -xzf nghttp3.tar.gz && \
    cd nghttp3-${NGHTTP3_VERSION} && \
    autoreconf -i && \
    ./configure --prefix=/usr/local --enable-lib-only && \
    make -j"$(nproc)" && \
    make install

RUN curl -sSL "${NGTCP2_URL}/v${NGTCP2_VERSION}/ngtcp2-${NGTCP2_VERSION}.tar.gz" -o ngtcp2.tar.gz && \
    echo "${NGTCP2_SHA256}  ngtcp2.tar.gz" | sha256sum -c - && \
    tar -xzf ngtcp2.tar.gz && \
    cd ngtcp2-${NGTCP2_VERSION} && \
    autoreconf -i && \
    ./configure \
      --prefix=/usr/local/ngtcp2 \
      --enable-lib-only \
      --with-openssl=/usr/local/openssl \
      --with-nghttp3=/usr/local && \
    make -j"$(nproc)" && \
    make install && \
    apk del --no-cache .build-deps && \
    rm -rf \
      /usr/share/man \
      /usr/share/docs \
      /tmp/* \
      /var/tmp/* \
      /var/log/*
