FROM alpine:latest AS openssl

WORKDIR /tmp/src

RUN apk --no-cache add curl build-base perl linux-headers ca-certificates; \
  ARCH=$(apk --print-arch); \
  case "$ARCH" in \
    armhf) export CFLAGS="-march=armv7-a -mthumb -mfpu=neon -mfloat-abi=hard" ;; \
    armv6) export CFLAGS="-march=armv6 -mfloat-abi=hard" ;; \
    *) export CFLAGS="" ;; \
  esac; \
  export CXXFLAGS="$CFLAGS"; \
  V=$(curl -s https://api.github.com/repos/openssl/openssl/releases/latest | sed -n 's/.*"tag_name": "\(.*\)".*/\1/p'); \
  curl -sSL https://github.com/openssl/openssl/releases/download/${V}/openssl-${V}.tar.gz -o o.tar.gz; \
  curl -sSL https://github.com/openssl/openssl/releases/download/${V}/openssl-${V}.tar.gz.sha256 -o o.sha256 || true; \
  if [ -f o.sha256 ]; then sha256sum -c o.sha256; fi; \
  tar -xzf o.tar.gz; \
  cd openssl-${V}; \
  ./Configure \
    linux-armv4 \
    enable-quic \
    enable-ktls \
    enable-tls1_3 \
    threads \
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

ENV PKG_CONFIG_PATH=/usr/local/openssl/lib/pkgconfig
ENV LD_LIBRARY_PATH=/usr/local/openssl/lib

RUN apk --no-cache add curl build-base autoconf automake libtool linux-headers ca-certificates; \
  ARCH=$(apk --print-arch); \
  case "$ARCH" in \
    armhf) export CFLAGS="-march=armv7-a -mthumb -mfpu=neon -mfloat-abi=hard" ;; \
    armv6) export CFLAGS="-march=armv6 -mfloat-abi=hard" ;; \
    *) export CFLAGS="" ;; \
  esac; \
  export CXXFLAGS="$CFLAGS"; \
  H=$(curl -s https://api.github.com/repos/ngtcp2/nghttp3/releases/latest | sed -n 's/.*"tag_name": "v\(.*\)".*/\1/p'); \
  curl -sSL https://github.com/ngtcp2/nghttp3/releases/download/v${H}/nghttp3-${H}.tar.gz -o h.tar.gz; \
  tar -xzf h.tar.gz; \
  cd nghttp3-${H}; \
  autoreconf -i; \
  ./configure --prefix=/usr/local --enable-lib-only; \
  make -j$(nproc); \
  make install; \
  cd /tmp/src; \
  V=$(curl -s https://api.github.com/repos/ngtcp2/ngtcp2/releases/latest | sed -n 's/.*"tag_name": "v\(.*\)".*/\1/p'); \
  curl -sSL https://github.com/ngtcp2/ngtcp2/releases/download/v${V}/ngtcp2-${V}.tar.gz -o n.tar.gz; \
  tar -xzf n.tar.gz; \
  cd ngtcp2-${V}; \
  autoreconf -i; \
  ./configure \
    --prefix=/usr/local/ngtcp2 \
    --enable-lib-only \
    --with-openssl=/usr/local/openssl \
    --with-nghttp3=/usr/local; \
  make -j$(nproc); \
  make install; \
  apk del build-base autoconf automake libtool linux-headers; \
  rm -rf /usr/share/man /usr/share/docs /tmp/* /var/tmp/* /var/log/*
