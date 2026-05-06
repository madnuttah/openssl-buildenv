ARG TARGETPLATFORM
ARG TARGETARCH
ARG BUILDENV_BUILD_DATE
ARG OPENSSL_BUILDENV_VERSION
ARG OPENSSL_VERSION
ARG OPENSSL_SHA256
ARG NGTCP2_VERSION
ARG NGHTTP3_VERSION
ARG SFPARSE_VERSION
ARG QUIC_BUILDENV_VERSION

FROM --platform=$TARGETPLATFORM alpine:latest AS openssl-build

ARG TARGETARCH
ARG BUILDENV_BUILD_DATE
ARG OPENSSL_BUILDENV_VERSION
ARG OPENSSL_VERSION
ARG OPENSSL_SHA256

LABEL maintainer="madnuttah" \
      build_date="${BUILDENV_BUILD_DATE}" \
      openssl_buildenv_version="${OPENSSL_BUILDENV_VERSION}" \
      openssl_version="${OPENSSL_VERSION}"

RUN apk add --no-cache build-base perl git ca-certificates curl linux-headers bash perl-utils

WORKDIR /src

RUN curl -LO https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz && \
    echo "${OPENSSL_SHA256}  openssl-${OPENSSL_VERSION}.tar.gz" | sha256sum -c - && \
    tar -xf openssl-${OPENSSL_VERSION}.tar.gz && \
    mv openssl-${OPENSSL_VERSION} openssl

WORKDIR /src/openssl

RUN case "$TARGETARCH" in \
      amd64) CONF="linux-x86_64"; EXTRA="enable-ec_nistp_64_gcc_128 enable-ktls"; OUT="linux_64";; \
      386)   CONF="linux-x86";    EXTRA=""; OUT="linux_386";; \
      arm)   CONF="linux-armv4";  EXTRA=""; OUT="linux_32";; \
      *) echo "Unsupported arch: $TARGETARCH"; exit 1;; \
    esac && \
    ./Configure \
      ${CONF} \
      no-weak-ssl-ciphers \
      no-apps \
      no-docs \
      no-legacy \
      no-ssl3 \
      no-err \
      no-autoerrinit \
      enable-tfo \
      enable-quic \
      ${EXTRA} \
      --prefix=/usr/local/openssl && \
    make -j"$(nproc)" && \
    make install_sw && \
    mkdir -p /out/${OUT} && \
    cp -r /usr/local/openssl /out/${OUT}

FROM alpine:latest AS quic-build

ARG BUILDENV_BUILD_DATE
ARG OPENSSL_VERSION
ARG NGTCP2_VERSION
ARG NGHTTP3_VERSION
ARG SFPARSE_VERSION

LABEL maintainer="madnuttah" \
      build_date="${BUILDENV_BUILD_DATE}" \
      openssl_version="${OPENSSL_VERSION}" \
      ngtcp2_version="${NGTCP2_VERSION}" \
      nghttp3_version="${NGHTTP3_VERSION}" \
      sfparse_version="${SFPARSE_VERSION}"

ENV PREFIX="/usr/local" \
    PKG_CONFIG_PATH="/usr/local/openssl/lib/pkgconfig:/usr/local/lib/pkgconfig" \
    PATH="/usr/local/bin:${PATH}"

WORKDIR /tmp/src

RUN apk add --no-cache \
    ca-certificates curl file git autoconf automake libtool pkgconfig \
    build-base perl libev-dev linux-headers python3 gnupg bash cmake \
    pkgconf make jq && \
    apk add --no-cache --virtual .build-deps gettext-dev

COPY --from=openssl-build /usr/local/openssl /usr/local/openssl

RUN git clone --branch "${SFPARSE_VERSION}" https://github.com/ngtcp2/sfparse.git && \
    cd sfparse && autoreconf -i && ./configure --prefix=/usr/local && \
    make -j"$(nproc)" && make install

RUN NGHTTP3_URL=$(curl -s https://api.github.com/repos/ngtcp2/nghttp3/releases \
      | jq -r ".[] | select(.tag_name==\"${NGHTTP3_VERSION}\") | .assets[] | select(.name | endswith(\".tar.gz\")) | .browser_download_url") && \
    curl -L "$NGHTTP3_URL" -o nghttp3.tar.gz && \
    mkdir nghttp3 && tar -xf nghttp3.tar.gz -C nghttp3 --strip-components=1 && \
    cd nghttp3 && autoreconf -i && \
    ./configure --prefix=/usr/local --enable-lib-only && \
    make -j"$(nproc)" && make install

RUN NGTCP2_URL=$(curl -s https://api.github.com/repos/ngtcp2/ngtcp2/releases \
      | jq -r ".[] | select(.tag_name==\"${NGTCP2_VERSION}\") | .assets[] | select(.name | endswith(\".tar.gz\")) | .browser_download_url") && \
    curl -L "$NGTCP2_URL" -o ngtcp2.tar.gz && \
    mkdir ngtcp2 && tar -xf ngtcp2.tar.gz -C ngtcp2 --strip-components=1 && \
    cd ngtcp2 && autoreconf -i && \
    PKG_CONFIG_PATH="/usr/local/openssl/lib/pkgconfig:/usr/local/lib/pkgconfig" \
      ./configure --prefix=/usr/local/ngtcp2 --enable-lib-only --with-openssl=/usr/local/openssl && \
    make -j"$(nproc)" && make install

RUN find /usr/local -type f -executable -exec strip --strip-all {} + || true && \
    rm -rf /tmp/* /var/tmp/* /var/log/* && \
    apk del --no-cache .build-deps

FROM alpine:latest AS final

COPY --from=quic-build /usr/local /usr/local

ENV LD_LIBRARY_PATH="/usr/local/lib:/usr/local/openssl/lib:/usr/local/ngtcp2/lib"
