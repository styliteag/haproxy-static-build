# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo builds

A multi-arch (linux/amd64 + linux/arm64) **statically linked** HAProxy binary, produced by a multi-stage Alpine Dockerfile that compiles HAProxy against statically built OpenSSL, PCRE2, and zlib. The final stage is `FROM scratch` and exports just `/haproxy`.

## Build

- `./build.sh` — the only entry point. Runs `docker buildx build --platform linux/amd64,linux/arm64 --output type=local,dest=./dist .`. Output is binaries (not images) under `./dist/linux_amd64/` and `./dist/linux_arm64/`.
- Do **not** run `./build.sh` to verify edits unless asked. Multi-arch builds are slow and the user does not want auto-verification.

## Toolchain gotchas (don't re-break these)

These are encoded in Dockerfile comments but worth reinforcing — past commits exist solely to fix each of these:

- **Use `gcc`, not `musl-gcc`**, for zlib / PCRE2 / OpenSSL `./configure` and `./Configure`. Alpine's `gcc` already targets musl. (Past breakage: 6a99d65)
- **OpenSSL `./Configure` target must be `linux-x86_64` / `linux-aarch64` / `linux-armv4`**, NOT `*-linux-musl` triplets. OpenSSL 3.5+ rejects the musl triplets after seed setup. The Dockerfile picks the right one from `${TARGETARCH}` into `/tmp/openssl_target`. (Past breakage: 0d3770e)
- **HAProxy `make` uses `TARGET=linux-musl`** — that's HAProxy's own target naming and is correct.
- **Do not add `--platform` to the `FROM alpine` line.** Let BuildKit pick from `TARGETPLATFORM`. Forcing `BUILDPLATFORM` mismatches when cross-building (e.g. Apple Silicon → linux/amd64). (Past breakage: 8515a29)
- **Static linkage is the whole point.** HAProxy is built with `ADDLIB="-static"` and `LDFLAGS="-static"`, then `strip`ped. Don't drop these.
- **Do not combine `USE_STATIC_PCRE2=1` with `LDFLAGS="-static"`.** `USE_STATIC_PCRE2=1` wraps PCRE2 in `-Wl,-Bstatic ... -Wl,-Bdynamic`; with a global `-static` the trailing `-Bdynamic` makes ld try to link `libc.so` (→ "attempted static link of dynamic object libc.so"). The global `-static` already forces `libpcre2-8.a` from `PCRE2_LIB`.
- **OpenSSL `./Configure` needs `--libdir=lib`.** The `linux-x86_64` target defaults `libdir` to `lib64` (multilib), while `linux-aarch64` uses `lib`. Forcing `--libdir=lib` keeps `/opt/openssl/lib/lib{ssl,crypto}.a` consistent with HAProxy's `SSL_LIB=/opt/openssl/lib`.

## Version pins

All upstream versions are pinned via `ARG` at the top of the Dockerfile:

- `HAPROXY_VERSION`, `OPENSSL_VERSION`, `PCRE2_VERSION`, `ZLIB_VERSION`, `ALPINE_VERSION`.

Bump versions only by editing those ARGs. The HAProxy download URL embeds the major.minor (`download/3.3/src/...`) — update that path too if bumping across a minor release.

## Repo etiquette

- Single `main` branch, no remote configured.
- Commit style (from history): short imperative subject, e.g. `Refactor Dockerfile to ...`, `Update Dockerfile to ...`.
