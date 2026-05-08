ARG TARGETPLATFORM
ARG TARGETARCH

FROM alpine:latest AS buildenv

ARG TARGETARCH
ARG BUILDENV_BUILD_DATE
ARG OPENSSL_BUILDENV_VERSION
ARG OPENSSL_VERSION
ARG OPENSSL_SHA256
ARG NGTCP2_VERSION
ARG NGHTTP3_VERSION
ARG QUIC_BUILDENV_VERSION

ENV BUILDENV_BUILD_DATE="${BUILDENV_BUILD_DATE}"

LABEL maintainer="madnuttah" \
      build_date="${BUILDENV_BUILD_DATE}" \
      openssl_buildenv_version="${OPENSSL_BUILDENV_VERSION}" \
      openssl_version="${OPENSSL_VERSION}" \
      quic_buildenv_version="${QUIC_BUILDENV_VERSION}"

ENV PREFIX="/usr/local" \
    PATH="/usr/local/openssl/bin:/usr/local/bin:${PATH}" \
    PKG_CONFIG_PATH="/usr/local/openssl/lib/pkgconfig:/usr/local/lib/pkgconfig"

RUN apk add --no-cache \
    build-base perl git ca-certificates curl linux-headers bash perl-utils \
    autoconf automake libtool pkgconfig libev-dev python3 gnupg cmake pkgconf jq \
    gettext-dev

WORKDIR /src

RUN curl -L "https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz" \
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

WORKDIR /src

RUN git clone https://github.com/ngtcp2/sfparse.git && \
    cd sfparse && autoreconf -i && ./configure --prefix=/usr/local --disable-static && \
    make -j"$(nproc)" && make install

RUN NGHTTP3_URL=$(curl -s https://api.github.com/repos/ngtcp2/nghttp3/releases \
      | jq -r ".[] | select(.tag_name==\"${NGHTTP3_VERSION}\") | .assets[] | select(.name | endswith(\".tar.gz\")) | .browser_download_url") && \
    curl -L "$NGHTTP3_URL" -o nghttp3.tar.gz && \
    mkdir nghttp3 && tar -xf nghttp3.tar.gz -C nghttp3 --strip-components=1 && \
    cd nghttp3 && autoreconf -i && \
    PKG_CONFIG_PATH="/usr/local/openssl/lib/pkgconfig:/usr/local/lib/pkgconfig" \
      ./configure --prefix=/usr/local \
                  --enable-lib-only \
                  --enable-optimizations \
                  --disable-static && \
    make -j"$(nproc)" && make install

RUN NGTCP2_URL=$(curl -s https://api.github.com/repos/ngtcp2/ngtcp2/releases \
      | jq -r ".[] | select(.tag_name==\"${NGTCP2_VERSION}\") | .assets[] | select(.name | endswith(\".tar.gz\")) | .browser_download_url") && \
    curl -L "$NGTCP2_URL" -o ngtcp2.tar.gz && \
    mkdir ngtcp2 && tar -xf ngtcp2.tar.gz -C ngtcp2 --strip-components=1 && \
    cd ngtcp2 && autoreconf -i && \
    PKG_CONFIG_PATH="/usr/local/openssl/lib/pkgconfig:/usr/local/lib/pkgconfig" \
      ./configure --prefix=/usr/local/ngtcp2 \
                  --enable-lib-only \
                  --enable-optimizations \
                  --with-openssl=/usr/local/openssl \
                  --disable-static && \
    make -j"$(nproc)" && make install

RUN rm -f /usr/local/lib/*.a /usr/local/lib/*.la && \
    strip --strip-unneeded /usr/local/lib/*.so* || true && \
    strip --strip-all /usr/local/bin/* || true && \
    rm -rf /src /tmp/* /var/tmp/* /var/log/* && \
    apk del gettext-dev

FROM alpine:latest AS final

COPY --from=buildenv /usr/local /usr/local

ENV LD_LIBRARY_PATH="/usr/local/lib:/usr/local/openssl/lib:/usr/local/ngtcp2/lib"
