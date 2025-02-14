FROM alpine:latest AS openssl

LABEL maintainer="madnuttah"
    
WORKDIR /tmp/src

RUN set -xe; \
  apk --update --no-cache add \
  ca-certificates \
  file && \
  apk --update --no-cache add --virtual .build-deps \
    build-base \
    perl \
    libidn2-dev \
    git \
    linux-headers && \
    git clone https://github.com/quictls/openssl openssl+quic && \
    cd openssl+quic && \
    ./config \
      enable-tls1_3 \
      no-shared \
      threads \
      no-weak-ssl-ciphers \
      no-ssl3 \
      no-err \
      no-autoerrinit \
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
    apk del --no-cache .build-deps
    
FROM alpine:latest AS buildenv

WORKDIR /tmp/src

COPY --from=openssl /usr/local/openssl/ \
  /usr/local/openssl/

RUN set -xe; \
  apk --update --no-cache add \
  ca-certificates \
  file && \
  apk --update --no-cache add --virtual .build-deps \
    build-base \
    perl \
    git \
    automake \
    autoconf \
    libtool \
    libidn2-dev \
    linux-headers && \
    git clone --depth 1 -b v0.19.1 https://github.com/ngtcp2/ngtcp2 ngtcp2 && \
    cd ngtcp2 && \
    autoreconf -i && \
    ./configure \
      PKG_CONFIG_PATH=/usr/local/openssl/lib/pkgconfig \
      LDFLAGS="-Wl,-rpath,/usr/local/openssl/lib" \
      --prefix=/usr/local/ngtcp2 && \
    make && \
    make install && \
    apk del --no-cache .build-deps && \
    rm -rf \
      /usr/share/man \
      /usr/share/docs \
      /usr/local/openssl/bin \
      /tmp/* \
      /var/tmp/* \
      /var/log/* 
    