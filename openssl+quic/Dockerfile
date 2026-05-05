ARG BUILDENV_BUILD_DATE
ARG OPENSSL_BUILDENV_VERSION
ARG OPENSSL_VERSION
ARG OPENSSL_SHA256

FROM madnuttah/openssl-buildenv:${OPENSSL_BUILDENV_VERSION} AS buildenv

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
  apk add --no-cache ca-certificates curl file git autoconf automake libtool pkgconfig build-base perl libev-dev linux-headers python3 gnupg bash cmake pkgconf make jq; \
  apk add --no-cache --virtual .build-deps gettext-dev; \
  mkdir -p /tmp/src; cd /tmp/src; \
  git clone https://github.com/ngtcp2/sfparse.git; \
  cd sfparse; autoreconf -i; ./configure --prefix=/usr/local; make -j$(nproc); make install; \
  ldconfig || true; \
  cd /tmp/src; \
  NGHTTP3_URL=$(curl -s https://api.github.com/repos/ngtcp2/nghttp3/releases/latest \
    | jq -r '.assets[] | select(.name | endswith(".tar.gz")) | .browser_download_url'); \
  NGHTTP3_ASC=$(curl -s https://api.github.com/repos/ngtcp2/nghttp3/releases/latest \
    | jq -r '.assets[] | select(.name | endswith(".tar.gz.asc")) | .browser_download_url'); \
  curl -L "$NGHTTP3_URL" -o nghttp3.tar.gz; \
  curl -L "$NGHTTP3_ASC" -o nghttp3.tar.gz.asc || true; \
  gpg --keyserver keyserver.ubuntu.com --recv-keys 0xEB4B1D6A5D81C5F4 || true; \
  echo "Imported GPG key belongs to:"; \
  gpg --list-keys --with-colons | grep '^uid' | cut -d: -f10; \
  gpg --verify nghttp3.tar.gz.asc nghttp3.tar.gz || true; \
  mkdir nghttp3; tar -xf nghttp3.tar.gz -C nghttp3 --strip-components=1; \
  cd nghttp3; autoreconf -i; ./configure --prefix=/usr/local --enable-lib-only; make -j$(nproc); make install; \
  cd /tmp/src; \
  NGTCP2_URL=$(curl -s https://api.github.com/repos/ngtcp2/ngtcp2/releases/latest \
    | jq -r '.assets[] | select(.name | endswith(".tar.gz")) | .browser_download_url'); \
  NGTCP2_ASC=$(curl -s https://api.github.com/repos/ngtcp2/ngtcp2/releases/latest \
    | jq -r '.assets[] | select(.name | endswith(".tar.gz.asc")) | .browser_download_url'); \
  curl -L "$NGTCP2_URL" -o ngtcp2.tar.gz; \
  curl -L "$NGTCP2_ASC" -o ngtcp2.tar.gz.asc || true; \
  echo "Imported GPG key belongs to:"; \
  gpg --list-keys --with-colons | grep '^uid' | cut -d: -f10; \
  gpg --verify ngtcp2.tar.gz.asc ngtcp2.tar.gz || true; \
  mkdir ngtcp2; tar -xf ngtcp2.tar.gz -C ngtcp2 --strip-components=1; \
  cd ngtcp2; \
  autoreconf -i; \
  PKG_CONFIG_PATH="/usr/local/openssl/lib/pkgconfig:/usr/local/lib/pkgconfig" \
    ./configure --prefix=/usr/local --enable-lib-only --with-openssl; \
  make -j$(nproc); make install; \
  rm -rf /tmp/* /var/tmp/* /var/log/*; \
  command -v strip >/dev/null 2>&1 && find /usr/local/bin /usr/local/lib -type f -executable -exec strip --strip-all {} + || true; \
  apk del --no-cache .build-deps
