ARG TARGETPLATFORM
ARG TARGETARCH

FROM alpine:latest AS buildenv

ARG TARGETARCH
ARG BUILDENV_BUILD_DATE
ARG OPENSSL_BUILDENV_VERSION
ARG OPENSSL_VERSION
ARG OPENSSL_SHA256

ENV BUILDENV_BUILD_DATE="${BUILDENV_BUILD_DATE}"

LABEL maintainer="madnuttah" \
      build_date="${BUILDENV_BUILD_DATE}" \
      openssl_buildenv_version="${OPENSSL_BUILDENV_VERSION}" \
      openssl_version="${OPENSSL_VERSION}"

ENV PREFIX="/usr/local" \
    PATH="/usr/local/openssl/bin:/usr/local/bin:${PATH}" \
    PKG_CONFIG_PATH="/usr/local/openssl/lib/pkgconfig:/usr/local/lib/pkgconfig"

# --- Improvement: add --no-cache to curl, remove unnecessary cache layers
RUN apk add --no-cache \
    build-base perl git ca-certificates curl linux-headers bash perl-utils \
    autoconf automake libtool pkgconfig libev-dev python3 gnupg cmake pkgconf jq \
    gettext-dev

WORKDIR /src

# --- Improvement: curl with --fail and --no-progress-meter for reliability
RUN curl -L --fail --no-progress-meter \
      "https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz" \
      -o "openssl-${OPENSSL_VERSION}.tar.gz" && \
    echo "${OPENSSL_SHA256}  openssl-${OPENSSL_VERSION}.tar.gz" | sha256sum -c - && \
    tar -xf "openssl-${OPENSSL_VERSION}.tar.gz" && \
    mv "openssl-${OPENSSL_VERSION}" openssl

WORKDIR /src/openssl

RUN case "$TARGETARCH" in \
      amd64) CONF="linux-x86_64"; EXTRA="enable-ec_nistp_64_gcc_128 enable-ktls enable-asm";; \
      386)   CONF="linux-x86";    EXTRA="enable-asm";; \
      armv7) CONF="linux-armv4";  EXTRA="enable-asm";; \
      arm)   CONF="linux-armv4";  EXTRA="enable-asm";; \
      *) echo "Unsupported arch: $TARGETARCH"; exit 1;; \
    esac && \
    CFLAGS="-O3 -D_FORTIFY_SOURCE=2 -fstack-protector-strong -fstack-clash-protection -fpic -DOPENSSL_NO_HEARTBEATS" \
    LDFLAGS="-Wl,-z,relro,-z,now" \
    ./Configure \
      ${CONF} \
      ${EXTRA} \
      no-weak-ssl-ciphers \
      no-apps \
      no-docs \
      shared \
      no-legacy \
      no-err \
      no-autoerrinit \
      enable-tfo \
      --prefix=/usr/local/openssl \
      --openssldir=/usr/local/openssl \
      --libdir=/usr/local/openssl/lib && \
    make -j"$(nproc)" && \
    make install_sw

RUN rm -f /usr/local/lib/*.a /usr/local/lib/*.la && \
    rm -f /usr/local/openssl/lib/*.a /usr/local/openssl/lib/*.la && \
    strip --strip-unneeded /usr/local/lib/*.so* || true && \
    strip --strip-unneeded /usr/local/openssl/lib/*.so* || true && \
    strip --strip-all /usr/local/bin/* || true && \
    strip --strip-all /usr/local/openssl/bin/* || true && \
    rm -rf /src /tmp/* /var/tmp/* /var/log/* && \
    apk del gettext-dev

FROM alpine:latest AS final

apk add --no-cache ca-certificates

COPY --from=buildenv /usr/local /usr/local

ENV LD_LIBRARY_PATH="/usr/local/lib:/usr/local/openssl/lib"
