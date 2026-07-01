# Configuration

Everything user-facing is driven by `.env` (copy `.env.example`) and
rendered into `/etc/nginx/...` by `docker/entrypoint.sh` at container start
using `envsubst`, restricted to an explicit variable list (see
`TEMPLATE_VARS` in `docker/entrypoint.sh`) so nginx's own `$host`-style
variables are never touched.

## Variable reference

See `.env.example` for the authoritative, commented list. Summary:

| Variable | Used for |
|---|---|
| `DOMAIN` | Primary hostname; certificate path (`/etc/letsencrypt/live/$DOMAIN/`); first `server_name`. |
| `EXTRA_DOMAINS` | Extra `server_name` entries and certificate SANs. **Space separated.** |
| `LETSENCRYPT_EMAIL`, `LETSENCRYPT_STAGING` | Used by `scripts/init-letsencrypt.sh` and the `certbot` sidecar, not by nginx itself. |
| `NGINX_WORKER_PROCESSES` | `worker_processes` in `nginx/nginx.conf`. |
| `NGINX_RELOAD_INTERVAL` | How often `docker/reload-loop.sh` runs `nginx -s reload` to pick up renewed certs. |
| `*_BACKEND` | `host:port` of the real service behind each proxied port — see [Ports & protocols](ports.md). |
| `CUSTOM_TCP_1_PORT` / `CUSTOM_TCP_2_PORT` | Listen ports for the two free-form TCP slots (default `4040`/`44337`). |

## Pointing at your backends

Backends are addressed as `host:port`. If they run as other services in the
same `docker-compose.yml`/network, use the service name:

```env
IMAP_BACKEND=dovecot:143
SMTP_BACKEND=postfix:25
```

and add them to the `proxy-net` network so the `nginx` container can reach
them:

```yaml
services:
  dovecot:
    image: your-dovecot-image
    networks: [proxy-net]
  postfix:
    image: your-postfix-image
    networks: [proxy-net]
networks:
  proxy-net:
    external: true   # or merge into this repo's docker-compose.yml directly
```

If they run elsewhere, use a reachable hostname/IP, e.g.
`IMAP_BACKEND=10.0.0.5:143` or `IMAP_BACKEND=mail-internal.example.net:143`.

Changing a `*_BACKEND` value only requires restarting the `nginx` container
(`docker compose restart nginx`) — it's re-rendered from the templates on
every start.

## STARTTLS backends

For the plaintext/STARTTLS ports (25, 587, 143, 110, 119, 5222, 5269, see
[Architecture](architecture.md#tls-termination-model)), nginx forwards raw
TCP and does not participate in the STARTTLS handshake. If you want TLS to
actually be available on those ports, the **backend** needs its own
certificate. The simplest approach is to give the backend read access to the
same Let's Encrypt certificate this proxy uses:

```yaml
services:
  postfix:
    volumes:
      - ./data/certbot/conf/live/${DOMAIN}:/etc/postfix/tls:ro
```

and configure the backend (Postfix `smtpd_tls_cert_file`/`smtpd_tls_key_file`,
Dovecot `ssl_cert`/`ssl_key`, Prosody `certificates/`, etc.) to use
`fullchain.pem`/`privkey.pem` from that path. Since `certbot` renews in
place, the backend just needs to reload/restart periodically the same way
this proxy does (`docker/reload-loop.sh`).

## Adding another domain or vhost

1. Add the hostname to `EXTRA_DOMAINS` in `.env` (space separated).
2. Re-run `./scripts/init-letsencrypt.sh` (or `certbot certonly ... -d
   newhost.example.com --expand` against the existing cert) so the
   certificate covers it.
3. If it needs its own backend, either extend `server_name` in
   `nginx/conf.d/http/10-https-main.conf.template` /
   `20-https-admin.conf.template`, or add a new
   `nginx/conf.d/http/*.conf.template` file with its own `server {}` block
   and a matching backend variable wired through `docker/entrypoint.sh`'s
   `TEMPLATE_VARS` and `.env.example`.

## TLS ciphers/protocols

Shared by every TLS-terminating server block via
`nginx/snippets/ssl-params.conf.template`. Defaults to TLS 1.2/1.3 with a
modern cipher list (`ECDHE`/`DHE` + AEAD only, `ssl_prefer_server_ciphers
on`). Edit that one file to change it everywhere at once.

## Adding a third custom TCP port

`nginx/conf.d/stream/60-custom.conf.template` only wires up two slots
(`CUSTOM_TCP_1_*`/`CUSTOM_TCP_2_*`) because that's what the project spec
calls for (ports 4040 and 44337). To add a third, copy one of the two
`server { }` blocks in that file, pick new `CUSTOM_TCP_3_PORT`/
`CUSTOM_TCP_3_BACKEND` variable names, add them to `.env.example`, add them
to `TEMPLATE_VARS` in `docker/entrypoint.sh`, and expose the port in both
`docker/Dockerfile` (`EXPOSE`) and `docker-compose.yml` (`ports:`).
