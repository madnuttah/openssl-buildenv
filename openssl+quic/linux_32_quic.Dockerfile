ARG BUILDENV_BUILD_DATE \
    OPENSSL_VERSION \
    OPENSSL_SHA256 \
    OPENSSL_BUILDENV_VERSION

FROM alpine:latest AS openssl-build

LABEL maintainer="madnuttah"

ARG OPENSSL_VERSION \
    OPENSSL_SHA256

ENV OPENSSL_VERSION=${OPENSSL_VERSION} \
    OPENSSL_SHA256=${OPENSSL_SHA256} \
    OPENSSL_DOWNLOAD_URL="https://github.com/openssl/openssl/releases/download/openssl" \
    OPENSSL_PGP="BA5473A2B0587B07FB27CF2D216094DFD0CB81EF"

WORKDIR /tmp/src

RUN set -xe; \
  apk --update --no-cache add ca-certificates gnupg curl file jq && \
  apk --update --no-cache add --virtual .build-deps build-base perl libidn2-dev libevent-dev linux-headers apk-tools autoconf automake libtool pkgconf pkgconfig git && \
  if [ -z "${OPENSSL_VERSION}" ]; then \
    OPENSSL_VERSION=$(curl -s https://api.github.com/repos/quictls/quictls/releases/latest | jq -r .tag_name); \
    if [ -z "$OPENSSL_VERSION" ] || [ "$OPENSSL_VERSION" = "null" ]; then \
      OPENSSL_VERSION=$(curl -s https://api.github.com/repos/quictls/quictls/tags | jq -r '.[0].name'); \
    fi; \
  fi && \
  curl -sSL "${OPENSSL_DOWNLOAD_URL}-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz" -o openssl.tar.gz && \
  if [ -n "${OPENSSL_SHA256}" ]; then echo "${OPENSSL_SHA256}  ./openssl.tar.gz" | sha256sum -c -; fi && \
  curl -sSL "${OPENSSL_DOWNLOAD_URL}-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz.asc" -o openssl.tar.gz.asc || true && \
  GNUPGHOME="$(mktemp -d)" && export GNUPGHOME && \
  if [ -f openssl.tar.gz.asc ]; then gpg --no-tty --keyserver hkps://keys.openpgp.org --recv-keys "${OPENSSL_PGP}" && gpg --batch --verify openssl.tar.gz.asc openssl.tar.gz; fi && \
  tar xzf openssl.tar.gz && rm -f openssl.tar.gz openssl.tar.gz.asc && \
  cd "openssl-${OPENSSL_VERSION}" && \
  export CFLAGS="-O3 -m32 -fstack-protector-strong -fstack-clash-protection -march=i386 -fPIC" && \
  export LDFLAGS="-Wl,-O1" && \
  ./Configure \
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

ARG NGTCP2_VERSION

FROM alpine:latest AS ngtcp2-build

WORKDIR /tmp/src

COPY --from=openssl-build /usr/local/openssl /usr/local/openssl
COPY --from=openssl-build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

RUN set -xe; \
  apk --update --no-cache add ca-certificates curl jq pkgconf pkgconfig && \
  apk --update --no-cache add --virtual .build-deps build-base perl curl automake autoconf libtool libidn2-dev linux-headers pkgconf pkgconfig git && \
  if [ -z "${NGTCP2_VERSION}" ]; then \
    NGTCP2_VERSION=$(curl -s https://api.github.com/repos/ngtcp2/ngtcp2/releases/latest | jq -r .tag_name); \
    if [ -z "$NGTCP2_VERSION" ] || [ "$NGTCP2_VERSION" = "null" ]; then \
      NGTCP2_VERSION=$(curl -s https://api.github.com/repos/ngtcp2/ngtcp2/tags | jq -r '.[0].name'); \
    fi; \
  fi && \
  NGTCP2_DL_TAG="${NGTCP2_VERSION#v}" && \
  curl -sSL "https://github.com/ngtcp2/ngtcp2/releases/download/v${NGTCP2_DL_TAG}/ngtcp2-${NGTCP2_DL_TAG}.tar.gz" -o ngtcp2.tar.gz && \
  tar xzf ngtcp2.tar.gz && rm -f ngtcp2.tar.gz && \
  cd "ngtcp2-${NGTCP2_DL_TAG}" && autoreconf -i && \
  export PKG_CONFIG_PATH=/usr/local/openssl/lib/pkgconfig:$PKG_CONFIG_PATH && \
  export CPPFLAGS="-I/usr/local/openssl/include" && \
  export CFLAGS="-O3 -m32 -fstack-protector-strong -fstack-clash-protection -march=i386 -fPIC" && \
  export LDFLAGS="-L/usr/local/openssl/lib -Wl,-O1" && \
  ./configure --prefix=/usr/local/ngtcp2 --enable-lib-only --disable-shared && \
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
  rm -rf /tmp/src/* && \
  apk del --no-cache .build-deps && \
  rm -rf /usr/share/man /usr/share/docs /var/tmp/* /tmp/* /var/log/*

FROM alpine:latest AS runtime

RUN apk add --no-cache ca-certificates

COPY --from=ngtcp2-build /usr/local/openssl/lib /usr/local/openssl/lib
COPY --from=ngtcp2-build /usr/local/ngtcp2/lib /usr/local/ngtcp2/lib
COPY --from=ngtcp2-build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

RUN rm -rf /usr/local/openssl/lib/pkgconfig /usr/local/ngtcp2/lib/pkgconfig && \
    find /usr/local/openssl/lib -name '*.a' -exec strip --strip-unneeded {} \; || true && \
    find /usr/local/ngtcp2/lib -name '*.a' -exec strip --strip-unneeded {} \; || true && \
    rm -rf /var/cache/apk/*

ENV PKG_CONFIG_PATH=/usr/local/openssl/lib/pkgconfig:/usr/local/ngtcp2/lib/pkgconfig:$PKG_CONFIG_PATH
