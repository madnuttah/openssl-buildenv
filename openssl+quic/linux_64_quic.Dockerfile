ARG BUILDENV_BUILD_DATE \
    QUICTLS_VERSION_UPSTREAM \
    NGTCP2_VERSION

FROM alpine:latest AS quictls-build

LABEL maintainer="madnuttah"

ARG QUICTLS_VERSION_UPSTREAM
ARG NGTCP2_VERSION

ENV QUICTLS_VERSION=${QUICTLS_VERSION_UPSTREAM} \
    NGTCP2_VERSION=${NGTCP2_VERSION} \
    QUICTLS_PGP="8657ABB260F056B1E5190839D9C4D26D0E604491" \
    QUICTLS_URL="https://github.com/quictls/quictls/archive/refs/tags" \
    NGTCP2_URL="https://github.com/ngtcp2/ngtcp2/releases/download"

WORKDIR /tmp/src

RUN set -xe; \
  apk add --no-cache ca-certificates gnupg curl file jq build-base perl libidn2-dev libevent-dev linux-headers autoconf automake libtool pkgconf pkgconfig git musl-dev && \
  if [ -z "${QUICTLS_VERSION}" ]; then \
    QUICTLS_VERSION=$(curl -s https://api.github.com/repos/quictls/quictls/releases/latest | jq -r .tag_name); \
    if [ -z "$QUICTLS_VERSION" ] || [ "$QUICTLS_VERSION" = "null" ]; then \
      QUICTLS_VERSION=$(curl -s https://api.github.com/repos/quictls/quictls/tags | jq -r '.[0].name'); \
    fi; \
  fi && \
  curl -sSL "${QUICTLS_URL}/${QUICTLS_VERSION}.tar.gz" -o quictls.tar.gz && \
  curl -sSL "${QUICTLS_URL}/${QUICTLS_VERSION}.tar.gz.asc" -o quictls.tar.gz.asc || true && \
  GNUPGHOME="$(mktemp -d)" && export GNUPGHOME && \
  if [ -f quictls.tar.gz.asc ]; then gpg --no-tty --keyserver hkps://keys.openpgp.org --recv-keys "${QUICTLS_PGP}" && gpg --batch --verify quictls.tar.gz.asc quictls.tar.gz; fi && \
  tar xzf quictls.tar.gz && rm -f quictls.tar.gz quictls.tar.gz.asc && \
  cd quictls-* && \
  export CC="gcc -m32" && export AR=ar && export RANLIB=ranlib && \
  export CFLAGS="-O3 -m32 -fstack-protector-strong -fstack-clash-protection -march=i386 -fPIC" && \
  export LDFLAGS="-m32 -Wl,-O1" && \
  ./Configure \
    enable-ec_nistp_64_gcc_128 \
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
Version: ${QUICTLS_VERSION}
Libs: -L${libdir} -lssl -lcrypto
Cflags: -I${includedir}
EOF && \
  strip --strip-unneeded /usr/local/openssl/lib/*.a || true && \
  rm -rf /tmp/src/*

FROM quictls-build AS ngtcp2-build

WORKDIR /tmp/src

ARG NGTCP2_VERSION

COPY --from=quictls-build /usr/local/openssl /usr/local/openssl
COPY --from=quictls-build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

RUN set -xe; \
  apk add --no-cache ca-certificates curl jq build-base perl automake autoconf libtool libidn2-dev linux-headers pkgconf pkgconfig git musl-dev && \
  if [ -z "${NGTCP2_VERSION}" ]; then \
    NGTCP2_VERSION=$(curl -s https://api.github.com/repos/ngtcp2/ngtcp2/releases/latest | jq -r .tag_name); \
    if [ -z "$NGTCP2_VERSION" ] || [ "$NGTCP2_VERSION" = "null" ]; then \
      NGTCP2_VERSION=$(curl -s https://api.github.com/repos/ngtcp2/ngtcp2/tags | jq -r '.[0].name'); \
    fi; \
  fi && \
  NGTCP2_DL_TAG="${NGTCP2_VERSION#v}" && \
  curl -sSL "${NGTCP2_URL}/v${NGTCP2_DL_TAG}/ngtcp2-${NGTCP2_DL_TAG}.tar.gz" -o ngtcp2.tar.gz && \
  tar xzf ngtcp2.tar.gz && rm -f ngtcp2.tar.gz && \
  cd "ngtcp2-${NGTCP2_DL_TAG}" && autoreconf -i && \
  export PKG_CONFIG_PATH=/usr/local/openssl/lib/pkgconfig:$PKG_CONFIG_PATH && \
  export CC="gcc -m32" && \
  export CPPFLAGS="-I/usr/local/openssl/include -m32" && \
  export CFLAGS="-O3 -m32 -fstack-protector-strong -fstack-clash-protection -march=i386 -fPIC" && \
  export LDFLAGS="-m32 -L/usr/local/openssl/lib -Wl,-O1" && \
  ./configure --prefix=/usr/local/ngtcp2 --enable-lib-only --disable-shared --with-openssl=/usr/local/openssl && \
  make -j"$(nproc)" && \
  make install && \
  mkdir -p /usr/local/ngtcp2/lib/pkgconfig && \
  cat > /usr/local/ngtcp2/lib/pkgconfig/ngtcp2.pc <<'EOF'
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
  rm -rf /tmp/src/*

FROM --platform=linux/386 ngtcp2-build AS final-build

WORKDIR /tmp/src

COPY --from=ngtcp2-build /usr/local/openssl /usr/local/openssl
COPY --from=ngtcp2-build /usr/local/ngtcp2 /usr/local/ngtcp2
COPY --from=ngtcp2-build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

RUN set -xe; \
  cat > /tmp/src/test.c <<'EOF'
#include <stdio.h>
int main(void){ puts("ok"); return 0; }
EOF && \
  gcc -static -O2 -s -o /usr/local/bin/test /tmp/src/test.c -I/usr/local/openssl/include -I/usr/local/ngtcp2/include -L/usr/local/openssl/lib -L/usr/local/ngtcp2/lib -lcrypto -lngtcp2 && \
  strip --strip-all /usr/local/bin/test || true && \
  rm -rf /tmp/src/* && \
  rm -rf /usr/local/openssl/lib/pkgconfig /usr/local/ngtcp2/lib/pkgconfig /usr/local/openssl/include /usr/local/ngtcp2/include

FROM scratch AS runtime

COPY --from=final-build /usr/local/bin/test /usr/local/bin/test
COPY --from=ngtcp2-build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

ENTRYPOINT ["/usr/local/bin/test"]
