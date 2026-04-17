# haproxy-static-build

Build a **fully static** HAProxy binary for Linux (musl) using Alpine in Docker. Dependencies (zlib, PCRE2, OpenSSL) are built from source and linked statically; the result is suitable for minimal or `FROM scratch`–style images.

## Download prebuilt binary

Prebuilt static binaries are committed under `dist/`. `haproxy-latest` always points at the current version (currently **3.3.6**); pin to a specific version if you prefer reproducible fetches.

```sh
# linux/amd64 — latest
wget -O haproxy https://github.com/styliteag/haproxy-static-build/raw/main/dist/linux_amd64/haproxy-latest
chmod +x haproxy

# linux/arm64 — latest
wget -O haproxy https://github.com/styliteag/haproxy-static-build/raw/main/dist/linux_arm64/haproxy-latest
chmod +x haproxy

# pin to a specific version
wget -O haproxy https://github.com/styliteag/haproxy-static-build/raw/main/dist/linux_amd64/haproxy-3.3.6
```

## Requirements

- Docker with [Buildx](https://docs.docker.com/build/buildx/) and BuildKit enabled
- For multi-arch builds (e.g. `linux/arm64` on an `amd64` host), QEMU binfmt registration is usually required (Docker Desktop provides this; on Linux you may need `docker run --privileged tonistiigi/binfmt --install all` or similar)

## Build

From the repository root:

```sh
./build.sh
```

This runs `docker buildx build` for `linux/amd64` and `linux/arm64`, tags `haproxy-static:3.3`, and exports artifacts to **`./dist`** (`type=local`). With multiple platforms, BuildKit usually writes one directory per platform (for example `dist/linux_amd64/`, `dist/linux_arm64/`), each containing the image root with the binary as **`haproxy-<version>`** (for example `haproxy-3.3.6`).

### Single platform

```sh
docker buildx build --platform linux/amd64 --output type=local,dest=./dist -t haproxy-static:3.3 .
```

### Image only (no local export)

```sh
docker buildx build --platform linux/amd64 --load -t haproxy-static:3.3 .
```

The final stage is based on **`scratch`**; the binary is installed as **`/haproxy-<version>`** (for example `/haproxy-3.3.6`), matching `HAPROXY_VERSION`.

## Versions

Defaults are set in the `Dockerfile` as `ARG`s:

| Argument          | Role        |
|-----------------|-------------|
| `ALPINE_VERSION` | Base image  |
| `HAPROXY_VERSION` | HAProxy tarball |
| `OPENSSL_VERSION` | OpenSSL       |
| `PCRE2_VERSION`   | PCRE2         |
| `ZLIB_VERSION`    | zlib          |

Override at build time, for example:

```sh
docker buildx build --build-arg HAPROXY_VERSION=3.3.7 ...
```

## Features enabled

The build turns on OpenSSL, PCRE2 (static, with JIT), zlib, threading, and Prometheus exporter (`USE_PROMEX=1`). Adjust `Makefile` variables in the Dockerfile if you need a different feature set.
