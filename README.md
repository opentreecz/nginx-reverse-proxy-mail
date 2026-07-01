# nginx-reverse-proxy-mail

[![CI](https://github.com/opentreecz/nginx-reverse-proxy-mail/actions/workflows/ci.yml/badge.svg)](https://github.com/opentreecz/nginx-reverse-proxy-mail/actions/workflows/ci.yml)
[![Release](https://github.com/opentreecz/nginx-reverse-proxy-mail/actions/workflows/release.yml/badge.svg)](https://github.com/opentreecz/nginx-reverse-proxy-mail/actions/workflows/release.yml)
[![Docs](https://github.com/opentreecz/nginx-reverse-proxy-mail/actions/workflows/docs.yml/badge.svg)](https://github.com/opentreecz/nginx-reverse-proxy-mail/actions/workflows/docs.yml)
[![Docker image](https://img.shields.io/badge/ghcr.io-nginx--reverse--proxy--mail-blue?logo=docker)](https://github.com/opentreecz/nginx-reverse-proxy-mail/pkgs/container/nginx-reverse-proxy-mail)

A single **nginx**, compiled from source, acting as the TLS-terminating
reverse proxy in front of a mail platform (SMTP/IMAP/POP3), an XMPP server,
an NNTP server and one or more HTTP(S) backends — all secured with a single
set of **Let's Encrypt** certificates.

📖 Full documentation: **[opentreecz.github.io/nginx-reverse-proxy-mail](https://opentreecz.github.io/nginx-reverse-proxy-mail/)**

## What this is

* An nginx **built from source** on `debian:stable-slim`, with the
  `stream`, `stream_ssl`, `stream_ssl_preread`, `mail`, `mail_ssl` and
  `http_ssl`/`http_v2` modules enabled, statically linked against a
  freshly-built OpenSSL.
* A **stream-module** based TCP/TLS proxy for every mail/chat/news
  protocol port, so nginx never needs to understand SMTP/IMAP/POP3/NNTP/XMPP
  semantics — it just terminates TLS (where the port implies implicit TLS)
  and forwards bytes to the real service.
* An **http-module** vhost set for `80`/`443`/`8443` (HTTP redirect, ACME
  challenge, main site, admin/alt site).
* A `docker-compose.yml` that wires the proxy together with a `certbot`
  sidecar for automatic Let's Encrypt issuance/renewal.
* GitHub Actions that lint, build (multi-arch), test, release and publish
  the whole thing — plus a scheduled job that keeps the base image and
  nginx/OpenSSL versions current.

## Ports covered

| Port | Protocol | Handling |
|------|----------|----------|
| 25 | SMTP | stream passthrough (STARTTLS) |
| 587 | SMTP submission | stream passthrough (STARTTLS) |
| 465 | SMTPS | stream, TLS terminated by nginx |
| 143 | IMAP | stream passthrough (STARTTLS) |
| 993 | IMAPS | stream, TLS terminated by nginx |
| 110 | POP3 | stream passthrough (STARTTLS) |
| 995 | POP3S | stream, TLS terminated by nginx |
| 119 | NNTP | stream passthrough (STARTTLS) |
| 563 | NNTPS | stream, TLS terminated by nginx |
| 5222 | XMPP client | stream passthrough (STARTTLS) |
| 5223 | XMPP client (legacy TLS) | stream, TLS terminated by nginx |
| 5269 | XMPP server-to-server | stream passthrough (STARTTLS) |
| 80 | HTTP | http, ACME-01 challenge + redirect to 443 |
| 443 | HTTPS | http, TLS terminated by nginx |
| 8443 | HTTPS (admin/alt vhost) | http, TLS terminated by nginx |
| 4040 | custom TCP/HTTP | stream passthrough |
| 44337 | custom TCP/HTTP | stream passthrough |

See [`docs/ports.md`](docs/ports.md) for the rationale and how to repoint
each backend.

## Quick start

```bash
git clone https://github.com/opentreecz/nginx-reverse-proxy-mail.git
cd nginx-reverse-proxy-mail
cp .env.example .env
$EDITOR .env                     # set DOMAIN, EXTRA_DOMAINS, LETSENCRYPT_EMAIL, backends
./scripts/init-letsencrypt.sh    # first-time certificate issuance
docker compose up -d
```

See [`docs/index.md`](docs/index.md) and [`docs/letsencrypt.md`](docs/letsencrypt.md)
for the full walkthrough.

## Repository layout

```text
docker/       Dockerfile + build metadata for the from-source nginx image
nginx/        nginx.conf, conf.d templates (http/ and stream/), TLS snippets
scripts/      entrypoint, Let's Encrypt bootstrap, version-check, config test
docs/         MkDocs documentation site (published to GitHub Pages)
.github/      CI, release, scheduled-rebuild workflows + Dependabot
```

## Releases

Tagged releases (`vX.Y.Z`) publish:

* Multi-arch (`amd64`/`arm64`/`arm/v7`) Docker images to
  `ghcr.io/opentreecz/nginx-reverse-proxy-mail`
* A `nginx-config-<version>.tar.gz` artifact with `nginx/`, `docker-compose.yml`
  and `.env.example`
* A `docker-compose.yml` artifact for standalone download
* An SBOM for the image

See [`docs/release-process.md`](docs/release-process.md).

## License

See [`LICENSE`](LICENSE).
