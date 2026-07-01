# Architecture

## Why `stream`, not `mail`

nginx ships two different modules that look relevant here:

- **`ngx_mail_*`** (`--with-mail`) is a genuine IMAP/POP3/SMTP *proxy*, but
  it only proxies the protocol handshake/auth phase to a backend after
  validating credentials against an HTTP auth server you must run yourself,
  and it does not transparently forward the full arbitrary protocol stream
  (SMTP in particular is proxied only enough to hand off to a relay, not
  relay arbitrary mail traffic on nginx's behalf). It's designed for a
  specific "auth gateway in front of many backends" topology.
- **`ngx_stream_*`** (`--with-stream`) is a generic TCP/UDP proxy. It has no
  idea it's carrying IMAP, POP3, SMTP, NNTP or XMPP — it just moves bytes,
  optionally terminating TLS first if `ssl_preread`/`listen ... ssl` says so.

This project's brief is "reverse proxy for IMAP/POP3/SMTP/HTTP/HTTPS [and, from
the port list, NNTP and XMPP]" — i.e. a single, protocol-agnostic front door
that terminates TLS with one Let's Encrypt certificate and forwards
plaintext to whatever real IMAP/POP3/SMTP/NNTP/XMPP/HTTP server sits behind
it. `stream` is the correct tool for that job precisely because it doesn't
need to understand any of these protocols, and it uniformly covers NNTP and
XMPP too (which `ngx_mail` cannot proxy at all). The image is still compiled
`--with-mail --with-mail_ssl_module` so a future auth-gateway use case is
available without a rebuild, but the shipped configuration does not use it.
See `nginx/conf.d/stream/`.

## TLS termination model

Every port in [Ports & protocols](ports.md) is one of two kinds:

- **Implicit TLS** (465, 993, 995, 563, 5223, 443, 8443): the client speaks
  TLS from the first byte. nginx terminates TLS here using the shared
  Let's Encrypt certificate (`nginx/snippets/ssl-params.conf.template`) and
  forwards **plaintext** to the backend over the internal Docker network.
- **STARTTLS-capable / plaintext** (25, 587, 143, 110, 119, 5222, 5269):
  the client negotiates TLS *inside* the protocol after connecting in
  plaintext. Because `stream` doesn't parse the protocol, nginx cannot
  inject itself into that handshake — these ports are forwarded as raw TCP
  passthrough, and the STARTTLS upgrade (if any) happens directly between
  the client and the backend. This means the backend needs its own
  certificate for those ports if you want STARTTLS to actually offer TLS;
  reusing the same Let's Encrypt certificate files on the backend is the
  usual approach. See [Configuration](configuration.md#starttls-backends).

This split is why the proxy is only useful with backend services that are
reachable on a trusted internal network: for the STARTTLS ports, nginx is
not a security boundary for that connection's payload, only a router.

## Request flow

```text
Internet                    nginx (this project)                 Backend network
--------                    --------------------                 ----------------
:80  ───────────────────▶  ACME challenge / redirect
:443 ── TLS ────────────▶  terminate TLS ──── plaintext HTTP ──▶  HTTPS_BACKEND
:8443── TLS ────────────▶  terminate TLS ──── plaintext HTTP ──▶  ADMIN_HTTPS_BACKEND
:25/:587 ── plaintext ──▶  TCP passthrough ─────────────────────▶ SMTP_BACKEND / SMTP_SUBMISSION_BACKEND
:465 ── TLS ────────────▶  terminate TLS ──── plaintext TCP ───▶  SMTPS_BACKEND
:143/:110/:119/:5222/:5269 ─ plaintext ──▶ TCP passthrough ────▶  respective *_BACKEND
:993/:995/:563/:5223 ── TLS ─▶ terminate TLS ── plaintext TCP ──▶ respective *_BACKEND
:4040/:44337 ── as-is ──▶  TCP passthrough ──────────────────────▶ CUSTOM_TCP_*_BACKEND
```

## Image layout

A two-stage `docker/Dockerfile`:

1. **builder** (`debian:stable-slim`): downloads, GPG/checksum-verifies,
   optionally patches (`docker/patches/`), and compiles nginx + OpenSSL from
   source. See [Building the image](building.md).
2. **final** (`debian:stable-slim`): only the compiled `nginx` binary,
   runtime shared libraries, and this repo's config templates/scripts —
   no compiler toolchain, no source tarballs.

Configuration is templated: every file under `nginx/conf.d/**/*.template`
and `nginx/snippets/*.template` is rendered with `envsubst` by
`docker/entrypoint.sh` at container start, restricted to an explicit
variable allow-list so nginx's own `$variables` are never touched. See
[Configuration](configuration.md).
