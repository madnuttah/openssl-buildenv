FROM alpine:latest AS opensssl

LABEL maintainer="madnuttah"

WORKDIR /tmp/src

RUN set -xe; \
  apk --update --no-cache add \
    ca-certificates \
    jq \
    curl && \
  export OPENSSL_VERSION=$(curl -s https://api.github.com/repos/quictls/openssl/releases/latest | jq -r .tag_name); \
  apk --update --no-cache add --virtual .build-deps \
    build-base \
    perl \
    libidn2-dev \
    git \
    curl \
    linux-headers && \
  curl -sSL https://github.com/quictls/openssl/archive/refs/tags/${OPENSSL_VERSION}.tar.gz -o openssl.tar.gz && \
  tar -xzf openssl.tar.gz && \
  rm openssl.tar.gz && \
  cd openssl-${OPENSSL_VERSION} && \
  ./config \
    enable-tls1_3 \
    no-shared \
    no-pinshared \
    threads \
    no-weak-ssl-ciphers \
    no-ssl3 \
    no-err
