# Building the image

## What gets compiled, and why

`docker/Dockerfile` is a two-stage build. The **builder** stage
(`debian:stable-slim`):

1. Installs build tooling (`build-essential`, `libpcre2-dev`, `zlib1g-dev`,
   `perl`, `patch`, `gnupg`).
2. Downloads the nginx source tarball from `nginx.org`, verifies it against
   the three GPG keys nginx.org release tarballs are signed with (fingerprints
   in `docker/Dockerfile`), and applies any `docker/patches/nginx/*.patch`.
3. Downloads the OpenSSL source tarball from `openssl.org`, verifies its
   published SHA-256 checksum, and applies any
   `docker/patches/openssl/*.patch`.
4. Runs nginx's `./configure --with-openssl=/usr/src/openssl ...`, which
   builds OpenSSL *as part of* the nginx build and statically links it —
   the resulting `nginx` binary has no runtime dependency on the system's
   `libssl`, so the proxy's TLS stack version is controlled entirely by
   `docker/OPENSSL_VERSION`, independent of whatever Debian ships.
5. `make install DESTDIR=/build`.

Modules enabled: `http_ssl`, `http_v2`, `http_realip`, `http_gzip_static`,
`http_stub_status`, `http_auth_request`, `http_sub`, `http_secure_link`,
`stream`, `stream_ssl`, `stream_ssl_preread`, `stream_realip`, `mail`,
`mail_ssl` — see [Architecture](architecture.md) for why `stream` (not
`mail`) is what the shipped config actually uses.

The **final** stage is a fresh `debian:stable-slim` with only the compiled
binary, runtime shared libraries (`libpcre2-8-0`, `zlib1g`), `ca-certificates`,
`gettext-base` (for `envsubst`), `openssl` (CLI, for `scripts/test-config.sh`
and ad-hoc debugging), and this repo's config templates/scripts. No compiler,
no source tarballs.

## Version pinning

`docker/NGINX_VERSION` and `docker/OPENSSL_VERSION` pin exactly what gets
built. They're plain text files (one version string each) so they're easy
to `cat`, diff, and bump automatically — see
[Release process: staying current](release-process.md#staying-current).

## Building locally

```bash
docker buildx build -f docker/Dockerfile -t nginx-reverse-proxy-mail:local --load .
```

Override versions for a one-off build:

```bash
docker buildx build -f docker/Dockerfile \
  --build-arg NGINX_VERSION=1.26.3 \
  --build-arg OPENSSL_VERSION=3.4.0 \
  -t nginx-reverse-proxy-mail:local --load .
```

Validate the resulting config:

```bash
IMAGE=nginx-reverse-proxy-mail:local ./scripts/test-config.sh
```

## Multi-architecture builds

CI builds/publishes `linux/amd64`, `linux/arm64`, and `linux/arm/v7` using
Buildx + QEMU emulation (no cross-compilation toolchain — each architecture
is built natively under emulation, which is slower but avoids
cross-compiling OpenSSL/nginx). To reproduce locally:

```bash
docker buildx create --use   # once, if you don't already have a buildx builder
docker buildx build -f docker/Dockerfile \
  --platform linux/amd64,linux/arm64,linux/arm/v7 \
  -t nginx-reverse-proxy-mail:local .
```

(Multi-platform builds can't be `--load`ed as a single image; either build
one platform at a time with `--load`, or `--push` to a registry.)

## Backporting an urgent security fix

If a CVE fix lands upstream before the next nginx/OpenSSL point release,
drop a patch file in `docker/patches/nginx/` or `docker/patches/openssl/`
(see `docker/patches/README.md`) — it's applied automatically at build
time, in filename order. Remove it once `docker/NGINX_VERSION` /
`docker/OPENSSL_VERSION` moves past the release that includes the real fix.
