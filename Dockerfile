# syntax=docker/dockerfile:1.7

ARG ALPINE_VERSION=3.21
ARG HAPROXY_VERSION=3.3.6
# Omit --platform so BuildKit uses the build target platform (BUILDPLATFORM would mismatch when --platform differs from host, e.g. Apple Silicon -> linux/amd64).
FROM alpine:${ALPINE_VERSION} AS builder

ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG TARGETOS
ARG TARGETARCH

ARG HAPROXY_VERSION
ARG OPENSSL_VERSION=3.5.6
ARG PCRE2_VERSION=10.46
ARG ZLIB_VERSION=1.3.2

WORKDIR /build

RUN apk add --no-cache \
    bash \
    build-base \
    linux-headers \
    musl-dev \
    perl \
    coreutils \
    curl \
    tar \
    xz \
    make \
    cmake \
    ninja \
    patch

# OpenSSL 3.5+ ./Configure: *-linux-musl triplets fail after seed setup; use linux-* targets (Alpine gcc is still musl).
RUN case "${TARGETARCH}" in \
      amd64)  echo linux-x86_64  > /tmp/openssl_target ;; \
      arm64)  echo linux-aarch64 > /tmp/openssl_target ;; \
      arm)    echo linux-armv4   > /tmp/openssl_target ;; \
      *)      echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac

# ---- zlib (static) ----
RUN curl -fsSLO https://zlib.net/zlib-${ZLIB_VERSION}.tar.gz \
 && tar -xzf zlib-${ZLIB_VERSION}.tar.gz

RUN cd zlib-${ZLIB_VERSION} \
 && CC=gcc ./configure --static --prefix=/opt/zlib \
 && make -j"$(nproc)" \
 && make install

# ---- PCRE2 (static) ----
RUN curl -fsSLO https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${PCRE2_VERSION}/pcre2-${PCRE2_VERSION}.tar.gz \
 && tar -xzf pcre2-${PCRE2_VERSION}.tar.gz

RUN cd pcre2-${PCRE2_VERSION} \
 && CC=gcc ./configure \
      --prefix=/opt/pcre2 \
      --disable-shared \
      --enable-static \
      --enable-jit \
      --disable-pcre2grep-libz \
      --disable-pcre2grep-libbz2 \
      --disable-dependency-tracking \
 && make -j"$(nproc)" \
 && make install

# ---- OpenSSL (static) ----
RUN curl -fsSLO https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz \
 && tar -xzf openssl-${OPENSSL_VERSION}.tar.gz

RUN cd openssl-${OPENSSL_VERSION} \
 && OPENSSL_TARGET="$(cat /tmp/openssl_target)" \
 && CC=gcc ./Configure "${OPENSSL_TARGET}" \
      no-shared \
      no-module \
      no-tests \
      --prefix=/opt/openssl \
      --libdir=lib \
      --openssldir=/etc/ssl \
      -fPIC \
 && make -j"$(nproc)" \
 && make install_sw

# ---- HAProxy (static) ----
RUN curl -fsSLO https://www.haproxy.org/download/3.3/src/haproxy-${HAPROXY_VERSION}.tar.gz \
 && tar -xzf haproxy-${HAPROXY_VERSION}.tar.gz

RUN cd haproxy-${HAPROXY_VERSION} \
 && make -j"$(nproc)" \
      TARGET=linux-musl \
      CC=gcc \
      CPU=generic \
      USE_OPENSSL=1 \
      USE_PCRE2=1 \
      USE_PCRE2_JIT=1 \
      USE_ZLIB=1 \
      USE_THREAD=1 \
      USE_PROMEX=1 \
      SSL_INC=/opt/openssl/include \
      SSL_LIB=/opt/openssl/lib \
      PCRE2_INC=/opt/pcre2/include \
      PCRE2_LIB=/opt/pcre2/lib \
      ZLIB_INC=/opt/zlib/include \
      ZLIB_LIB=/opt/zlib/lib \
      ADDLIB="-static" \
      LDFLAGS="-static"

RUN cd haproxy-${HAPROXY_VERSION} \
 && strip haproxy \
 && ./haproxy -vv \
 && ldd haproxy || true \
 && file haproxy \
 && mkdir -p /out \
 && cp haproxy /out/haproxy-${HAPROXY_VERSION}

FROM scratch AS artifact
ARG HAPROXY_VERSION
COPY --from=builder /out/haproxy-${HAPROXY_VERSION} /haproxy-${HAPROXY_VERSION}
