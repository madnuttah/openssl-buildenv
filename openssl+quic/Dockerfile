ARG BUILDENV_BUILD_DATE
ARG OPENSSL_BUILDENV_VERSION
ARG OPENSSL_VERSION
ARG OPENSSL_SHA256

FROM alpine:latest AS buildenv

LABEL maintainer="madnuttah" \
      build_date="${BUILDENV_BUILD_DATE}" \
      openssl_version="${OPENSSL_VERSION}"

ENV PREFIX="/usr/local" \
    PKG_CONFIG_PATH="/usr/local/openssl/lib/pkgconfig:/usr/local/lib/pkgconfig" \
    PATH="/usr/local/bin:${PATH}" \
    OPENSSL_VERSION="${OPENSSL_VERSION}" \
    OPENSSL_SHA256="${OPENSSL_SHA256}"

WORKDIR /tmp/src

RUN set -xe; \
  apk add --no-cache \
    ca-certificates curl file git autoconf automake libtool pkgconfig \
    build-base perl libev-dev linux-headers python3 gnupg bash cmake \
    pkgconf make jq && \
  apk add --no-cache --virtual .build-deps gettext-dev && \
  git clone https://github.com/ngtcp2/sfparse.git; \
  cd sfparse; autoreconf -i; ./configure --prefix=/usr/local; make -j$(nproc); make install; \
  cd /tmp/src; \
  NGHTTP3_URL=$(curl -s https://api.github.com/repos/ngtcp2/nghttp3/releases/latest \
    | jq -r '.assets[] | select(.name | endswith(".tar.gz")) | .browser_download_url'); \
  curl -L "$NGHTTP3_URL" -o nghttp3.tar.gz; \
  mkdir nghttp3; tar -xf nghttp3.tar.gz -C nghttp3 --strip-components=1; \
  cd nghttp3; autoreconf -i; ./configure --prefix=/usr/local --enable-lib-only; \
  make -j$(nproc); make install; \
  cd /tmp/src; \
  NGTCP2_URL=$(curl -s https://api.github.com/repos/ngtcp2/ngtcp2/releases/latest \
    | jq -r '.assets[] | select(.name | endswith(".tar.gz")) | .browser_download_url'); \
  curl -L "$NGTCP2_URL" -o ngtcp2.tar.gz; \
  mkdir ngtcp2; tar -xf ngtcp2.tar.gz -C ngtcp2 --strip-components=1; \
  cd ngtcp2; autoreconf -i; \
  PKG_CONFIG_PATH="/usr/local/openssl/lib/pkgconfig:/usr/local/lib/pkgconfig" \
    ./configure --prefix=/usr/local/ngtcp2 --enable-lib-only --with-openssl=/usr/local/openssl; \
  make -j$(nproc); make install; \
  find /usr/local -type f -executable -exec strip --strip-all {} + || true; \
  rm -rf /tmp/* /var/tmp/* /var/log/*; \
  apk del --no-cache .build-deps
