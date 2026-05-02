FROM alpine:latest AS openssl

LABEL maintainer="madnuttah"

WORKDIR /tmp/src

RUN apk add --no-cache curl build-base perl linux-headers ca-certificates

RUN OPENSSL_VERSION=$(curl -s https://api.github.com/repos/openssl/openssl/releases/latest | sed -n 's/.*"tag_name": "\(.*\)".*/\1/p') && \
    curl -sSL "https://github.com/openssl/openssl/releases/download/${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz" -o openssl.tar.gz && \
    curl -sSL "https://github.com/openssl/openssl/releases/download/${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz.sha256" -o openssl.sha256 || true && \
    if [ -f openssl.sha256 ]; then sha256sum -c openssl.sha256; fi && \
    tar -xzf openssl.tar.gz && \
    cd openssl-${OPENSSL_VERSION} && \
    ./Configure \
      enable-quic \
      enable-tls1_3 \
      no-shared \
      no-pinshared \
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
    make -j"$(nproc)" && \
    make install_sw && \
    rm -rf /usr/local/openssl/bin /tmp/*

FROM alpine:latest AS buildenv

WORKDIR /tmp/src

COPY --from=openssl /usr/local/openssl/ /usr/local/openssl/

ENV PKG_CONFIG_PATH=/usr/local/openssl/lib/pkgconfig
ENV LD_LIBRARY_PATH=/usr/local/openssl/lib

RUN apk add --no-cache curl build-base perl automake autoconf libtool linux-headers ca-certificates

RUN NGHTTP3_VERSION=$(curl -s https://api.github.com/repos/ngtcp2/nghttp3/releases/latest | sed -n 's/.*"tag_name": "v\(.*\)".*/\1/p') && \
    curl -sSL "https://github.com/ngtcp2/nghttp3/releases/download/v${NGHTTP3_VERSION}/nghttp3-${NGHTTP3_VERSION}.tar.gz" -o nghttp3.tar.gz && \
    tar -xzf nghttp3.tar.gz && \
    cd nghttp3-${NGHTTP3_VERSION} && \
    autoreconf -i && \
    ./configure --prefix=/usr/local --enable-lib-only && \
    make -j"$(nproc)" && \
    make install

RUN NGTCP2_VERSION=$(curl -s https://api.github.com/repos/ngtcp2/ngtcp2/releases/latest | sed -n 's/.*"tag_name": "v\(.*\)".*/\1/p') && \
    curl -sSL "https://github.com/ngtcp2/ngtcp2/releases/download/v${NGTCP2_VERSION}/ngtcp2-${NGTCP2_VERSION}.tar.gz" -o ngtcp2.tar.gz && \
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
    rm -rf /tmp/* /var/tmp/* /var/log/*
