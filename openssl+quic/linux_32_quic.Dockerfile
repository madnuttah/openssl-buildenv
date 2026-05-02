FROM alpine:latest AS openssl

LABEL maintainer="madnuttah"

WORKDIR /tmp/src

RUN set -xe; \
  apk --no-cache add curl build-base perl linux-headers; \
  V=$(curl -s https://api.github.com/repos/quictls/openssl/releases/latest | grep tag_name | cut -d '"' -f4); \
  curl -sSL https://github.com/quictls/openssl/archive/refs/tags/${V}.tar.gz -o o.tar.gz; \
  tar -xzf o.tar.gz; \
  cd openssl-${V}; \
  ./config \
    linux-generic32 \
    -m32 \
    enable-quic \
    enable-ktls \
    enable-tls1_3 \
    threads \
    no-shared \
    no-pinshared \
    no-weak-ssl-ciphers \
    no-err \
    no-autoerrinit \
    no-shared \
    no-tests \
    -fPIC \
    --prefix=/usr/local/openssl \
    --openssldir=/usr/local/openssl \
    --libdir=/usr/local/openssl/lib; \
  make -j$(nproc); \
  make install_sw; \
  apk del build-base perl linux-headers; \
  rm -rf /usr/local/openssl/bin

FROM alpine:latest AS ngtcp2

WORKDIR /tmp/src

COPY --from=openssl /usr/local/openssl/ /usr/local/openssl/

RUN set -xe; \
  apk --no-cache add curl build-base autoconf automake libtool linux-headers; \
  V=$(curl -s https://api.github.com/repos/ngtcp2/ngtcp2/releases/latest | grep tag_name | cut -d '"' -f4 | sed 's/^v//'); \
  curl -sSL https://github.com/ngtcp2/ngtcp2/releases/download/v${V}/ngtcp2-${V}.tar.gz -o n.tar.gz; \
  tar -xzf n.tar.gz; \
  cd ngtcp2-${V}; \
  autoreconf -i; \
  ./configure \
    PKG_CONFIG_PATH=/usr/local/openssl/lib/pkgconfig \
    LDFLAGS="-Wl,-rpath,/usr/local/openssl/lib" \
    --prefix=/usr/local/ngtcp2 \
    --enable-openssl \
    --disable-boringssl
    --enable-lib-only; \
  make -j$(nproc); \
  make install; \
  apk del build-base autoconf automake libtool linux-headers; \
  rm -rf /usr/share/man /usr/share/docs /tmp/* /var/tmp/* /var/log/*
