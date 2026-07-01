# nginx-reverse-proxy-mail

A single **nginx**, compiled from source, acting as the TLS-terminating
reverse proxy in front of a mail platform (SMTP/IMAP/POP3), an XMPP server,
an NNTP server, and one or more HTTP(S) backends — all secured with one set
of **Let's Encrypt** certificates.

This project provides:

- An nginx **built from source** on `debian:stable-slim`, statically linked
  against a freshly built OpenSSL, with the `stream`, `stream_ssl`,
  `stream_ssl_preread`, `mail`, `mail_ssl`, `http_ssl` and `http_v2` modules
  enabled. See [Architecture](architecture.md) and [Building the image](building.md).
- Ready-made nginx configuration templates covering every port in
  [Ports & protocols](ports.md).
- A `docker-compose.yml` wiring the proxy together with a `certbot` sidecar
  for Let's Encrypt issuance/renewal — see [Let's Encrypt](letsencrypt.md).
- GitHub Actions that lint, build (multi-arch), test, release and publish the
  whole thing, and keep it current — see [CI/CD](ci-cd.md) and
  [Release process](release-process.md).

## Quick start

```bash
git clone https://github.com/opentreecz/nginx-reverse-proxy-mail.git
cd nginx-reverse-proxy-mail
cp .env.example .env
$EDITOR .env                     # DOMAIN, EXTRA_DOMAINS, LETSENCRYPT_EMAIL, *_BACKEND
./scripts/init-letsencrypt.sh    # first-time certificate issuance
docker compose up -d
```

By default `docker-compose.yml` pulls the published image
(`ghcr.io/opentreecz/nginx-reverse-proxy-mail:latest`). To build locally from
source instead:

```bash
docker compose build
docker compose up -d
```

## Prerequisites

- Docker Engine with the `compose` plugin (Docker Compose v2) and Buildx.
- A DNS `A`/`AAAA` record pointing `DOMAIN` (and every host in
  `EXTRA_DOMAINS`) at this host, **before** running `init-letsencrypt.sh` --
  Let's Encrypt's HTTP-01 challenge needs to reach port 80 here.
- Ports 80 and 443 (and whichever mail/XMPP/NNTP/custom ports you use)
  reachable from the internet/clients, i.e. not already bound by another
  process and open in any upstream firewall/security group.
- The actual backend services (Postfix/Dovecot/Prosody/your NNTP
  daemon/your web app) reachable from this host on the addresses configured
  in `.env` — this project is *only* the TLS-terminating proxy in front of
  them, not the mail/XMPP/NNTP/web stack itself.

## Where to go next

| I want to... | Read |
|---|---|
| Understand *why* it's built this way | [Architecture](architecture.md) |
| Know what each of the 17 ports does | [Ports & protocols](ports.md) |
| Change a backend, add a domain, tune TLS | [Configuration](configuration.md) |
| Understand certificate issuance/renewal | [Let's Encrypt](letsencrypt.md) |
| Build the image myself / add a patch | [Building the image](building.md) |
| Understand the CI checks on every PR | [CI/CD](ci-cd.md) |
| Cut a release / consume release artifacts | [Release process](release-process.md) |
| Fix something that isn't working | [Troubleshooting](troubleshooting.md) |
