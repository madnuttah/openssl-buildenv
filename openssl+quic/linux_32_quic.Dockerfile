FROM alpine:latest AS openssl

LABEL maintainer="madnuttah"

WORKDIR /tmp/src

RUN set -xe; \
  apk add --no-cache ca-certificates jq curl && \
  export OPENSSL_VERSION=$(curl -s https://api.github.com/repos/quictls/quictls/releases/latest | jq -r .tag_name); \
  echo "Using QuicTLS version: ${OPENSSL_VERSION}" && \
  apk add --no-cache --virtual .build-deps build-base perl libidn2-dev git curl linux-headers autoconf automake libtool pkgconf pkgconfig && \
  curl -sSL https://github.com/quictls/quictls/archive/refs/tags/${OPENSSL_VERSION}.tar.gz -o quictls.tar.gz && \
  tar -xzf quictls.tar.gz && \
  rm quictls.tar.gz && \
  cd quictls-${OPENSSL_VERSION} && \
  export CFLAGS="-O3 -fstack-protector-strong -fstack-clash-protection -fPIC" && \
  export LDFLAGS="-Wl,-O1" && \
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
    -DOPENSSL_NO_HEARTBEATS \
    --prefix=/usr/local/openssl \
    --openssldir=/usr/local/openssl \
    --libdir=/usr/local/openssl/lib && \
  make -j"$(nproc)" && \
  make install_sw && \
  mkdir -p /usr/local/openssl/lib/pkgconfig && \
  cat > /usr/local/openssl/lib/pkgconfig/openssl.pc <<'EOF'
prefix=/usr/local/openssl
exec_prefix=${prefix}
libdir=${exec_prefix}/lib
includedir=${prefix}/include
Name: OpenSSL
Description: QuicTLS OpenSSL fork
Version: ${OPENSSL_VERSION}
Libs: -L${libdir} -lssl -lcrypto
Cflags: -I${includedir}
EOF
  && rm -rf /tmp/src && \
  apk del --no-cache .build-deps


FROM alpine:latest AS buildenv

WORKDIR /tmp/src

COPY --from=openssl /usr/local/openssl /usr/local/openssl

RUN set -xe; \
  apk add --no-cache ca-certificates jq curl pkgconf pkgconfig && \
  export NGTCP2_VERSION=$(curl -s https://api.github.com/repos/ngtcp2/ngtcp2/releases/latest | jq -r .tag_name | sed 's/^v//'); \
  echo "Using ngtcp2 version: ${NGTCP2_VERSION}" && \
  apk add --no-cache --virtual .build-deps build-base perl curl automake autoconf libtool libidn2-dev linux-headers pkgconf pkgconfig && \
  curl -sSL https://github.com/ngtcp2/ngtcp2/releases/download/v${NGTCP2_VERSION}/ngtcp2-${NGTCP2_VERSION}.tar.gz -o ngtcp2.tar.gz && \
  tar -xzf ngtcp2.tar.gz && \
  rm ngtcp2.tar.gz && \
  cd ngtcp2-${NGTCP2_VERSION} && \
  autoreconf -i && \
  export PKG_CONFIG_PATH=/usr/local/openssl/lib/pkgconfig:$PKG_CONFIG_PATH && \
  export CPPFLAGS="-I/usr/local/openssl/include" && \
  export CFLAGS="-O3 -fstack-protector-strong -fstack-clash-protection -fPIC" && \
  export LDFLAGS="-L/usr/local/openssl/lib -Wl,-rpath,/usr/local/openssl/lib -Wl,-O1" && \
  ./configure --prefix=/usr/local/ngtcp2 && \
  make -j"$(nproc)" && \
  make install && \
  rm -rf /tmp/src && \
  apk del --no-cache .build-deps
