ARG BUILDENV_BUILD_DATE \
    OPENSSL_VERSION \
    OPENSSL_SHA256 \
    OPENSSL_BUILDENV_VERSION

FROM alpine:latest AS openssl

LABEL maintainer="madnuttah"

WORKDIR /tmp/src

RUN set -xe; \
  apk add --no-cache ca-certificates jq curl gnupg file && \
  if [ -z "${OPENSSL_VERSION}" ]; then \
    OPENSSL_VERSION=$(curl -s https://api.github.com/repos/quictls/quictls/releases/latest | jq -r .tag_name); \
    if [ -z "$OPENSSL_VERSION" ] || [ "$OPENSSL_VERSION" = "null" ]; then \
      OPENSSL_VERSION=$(curl -s https://api.github.com/repos/quictls/quictls/tags | jq -r '.[0].name'); \
    fi; \
  fi; \
  apk add --no-cache --virtual .build-deps build-base perl libidn2-dev git curl linux-headers autoconf automake libtool pkgconf pkgconfig && \
  curl -sSL "https://github.com/quictls/quictls/archive/refs/tags/${OPENSSL_VERSION}.tar.gz" -o quictls.tar.gz && \
  if [ -n "${OPENSSL_SHA256}" ]; then echo "${OPENSSL_SHA256}  ./quictls.tar.gz" | sha256sum -c -; fi && \
  tar -xzf quictls.tar.gz && rm -f quictls.tar.gz && \
  cd "quictls-${OPENSSL_VERSION}" && \
  export CFLAGS="-O3 -m32 -fstack-protector-strong -fstack-clash-protection -march=i386 -fPIC" && \
  export LDFLAGS="-Wl,-O1" && \
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
    no-ssl3 \
    no-err \
    no-autoerrinit \
    -DOPENSSL_NO_HEARTBEATS \
    -fstack-protector-strong \
    -fstack-clash-protection \
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
EOF && \
  strip --strip-unneeded /usr/local/openssl/lib/*.a || true && \
  rm -rf /tmp/src/* && \
  apk del --no-cache .build-deps && \
  pkill -9 gpg-agent || true && \
  pkill -9 dirmngr || true && \
  rm -rf /usr/share/man /usr/share/docs /var/tmp/* /tmp/* /var/log/*

FROM alpine:latest AS buildenv

WORKDIR /tmp/src

COPY --from=openssl /usr/local/openssl /usr/local/openssl

RUN set -xe; \
  apk add --no-cache ca-certificates jq curl pkgconf pkgconfig && \
  if [ -z "${NGTCP2_VERSION}" ]; then \
    NGTCP2_VERSION=$(curl -s https://api.github.com/repos/ngtcp2/ngtcp2/releases/latest | jq -r .tag_name); \
    if [ -z "$NGTCP2_VERSION" ] || [ "$NGTCP2_VERSION" = "null" ]; then \
      NGTCP2_VERSION=$(curl -s https://api.github.com/repos/ngtcp2/ngtcp2/tags | jq -r '.[0].name'); \
    fi; \
  fi; \
  NGTCP2_DL_TAG="${NGTCP2_VERSION#v}" && \
  apk add --no-cache --virtual .build-deps build-base perl curl automake autoconf libtool libidn2-dev linux-headers pkgconf pkgconfig && \
  curl -sSL "https://github.com/ngtcp2/ngtcp2/releases/download/v${NGTCP2_DL_TAG}/ngtcp2-${NGTCP2_DL_TAG}.tar.gz" -o ngtcp2.tar.gz && \
  tar -xzf ngtcp2.tar.gz && rm -f ngtcp2.tar.gz && \
  cd "ngtcp2-${NGTCP2_DL_TAG}" && \
  autoreconf -i && \
  export PKG_CONFIG_PATH=/usr/local/openssl/lib/pkgconfig:$PKG_CONFIG_PATH && \
  export CPPFLAGS="-I/usr/local/openssl/include" && \
  export CFLAGS="-O3 -m32 -fstack-protector-strong -fstack-clash-protection -march=i386 -fPIC" && \
  export LDFLAGS="-L/usr/local/openssl/lib -Wl,-rpath,/usr/local/openssl/lib -Wl,-O1" && \
  ./configure --prefix=/usr/local/ngtcp2 --enable-lib-only --disable-shared && \
  make -j"$(nproc)" && \
  make install && \
  mkdir -p /usr/local/ngtcp2/lib/pkgconfig && \
  cat > /usr/local/ngtcp2/lib/pkgconfig/ngtcp2.pc <<EOF
prefix=/usr/local/ngtcp2
exec_prefix=${prefix}
libdir=${exec_prefix}/lib
includedir=${prefix}/include
Name: ngtcp2
Description: ngtcp2 library
Version: ${NGTCP2_DL_TAG}
Libs: -L${libdir} -lngtcp2
Cflags: -I${includedir}
EOF && \
  strip --strip-unneeded /usr/local/ngtcp2/lib/*.a || true && \
  rm -rf /tmp/src/* && \
  apk del --no-cache .build-deps && \
  rm -rf /usr/share/man /usr/share/docs /var/tmp/* /tmp/* /var/log/*
