# Let's Encrypt

One certificate, covering `DOMAIN` + every host in `EXTRA_DOMAINS`, is used
by every TLS-terminating server block (443, 8443, 465, 993, 995, 563,
5223 — see [Ports & protocols](ports.md)).

## How it fits together

- `certbot` runs as its own service in `docker-compose.yml`, sharing two
  volumes with `nginx`:
  - `./data/certbot/conf` → `/etc/letsencrypt` (certificates, account keys, renewal config)
  - `./data/certbot/www` → `/var/www/certbot` (HTTP-01 challenge webroot)
- nginx serves `/.well-known/acme-challenge/` straight from that webroot on
  **port 80 only** (`nginx/conf.d/http/00-acme-http.conf.template`) — this
  is why port 80 must stay reachable from the internet, even though
  everything else on it just redirects to HTTPS.
- The `certbot` service's entrypoint loops `certbot renew` every 12 hours.
  `certbot renew` is a no-op unless a certificate is within its renewal
  window, so this is safe to run that often.
- `docker/reload-loop.sh` inside the `nginx` container runs `nginx -s
  reload` every `NGINX_RELOAD_INTERVAL` (default `12h`) so renewed
  certificates are picked up without a restart or any coordination between
  containers.

## First-time issuance

nginx cannot start with a `ssl_certificate` directive pointing at a file
that doesn't exist yet, and certbot cannot get a certificate until nginx is
already serving the HTTP-01 challenge on port 80 — `scripts/init-letsencrypt.sh`
breaks that cycle:

```bash
cp .env.example .env
$EDITOR .env   # DOMAIN, EXTRA_DOMAINS, LETSENCRYPT_EMAIL
./scripts/init-letsencrypt.sh
docker compose up -d
```

The script:

1. Generates a throwaway self-signed certificate at the path nginx expects.
2. Starts the `nginx` service (now able to start, since the file exists).
3. Deletes the throwaway certificate.
4. Runs `certbot certonly --webroot` for real, requesting `DOMAIN` +
   `EXTRA_DOMAINS`.
5. Reloads nginx so it picks up the real certificate.

**Before running it:** point DNS (`A`/`AAAA`) for `DOMAIN` and every
`EXTRA_DOMAINS` host at this server, and make sure port 80 is reachable from
the internet (not blocked by a firewall/security group, not already bound
by another process).

## Staging vs production

Let's Encrypt's production endpoint has tight rate limits per domain per
week. While testing, set:

```env
LETSENCRYPT_STAGING=1
```

Staging certificates aren't trusted by browsers/clients, but let you
validate the whole flow (DNS, port 80 reachability, webroot permissions)
without burning your production rate limit. Switch back to `0` once
everything works, then re-run `./scripts/init-letsencrypt.sh` (or just
`certbot certonly` again — see below) to get a trusted certificate.

## Renewal

Handled automatically by the `certbot` service once it's running — nothing
to do. To force an immediate renewal attempt (e.g. after changing
`EXTRA_DOMAINS`):

```bash
docker compose run --rm --entrypoint certbot certbot renew --webroot -w /var/www/certbot --force-renewal
docker compose exec nginx nginx -s reload
```

## Adding a domain to an existing certificate

```bash
docker compose run --rm --entrypoint certbot certbot certonly \
  --webroot -w /var/www/certbot \
  -d "$DOMAIN" -d newhost.example.com --expand
docker compose exec nginx nginx -s reload
```

Then add `newhost.example.com` to `EXTRA_DOMAINS` in `.env` so nginx's own
`server_name`/SAN expectations stay in sync, and `docker compose restart nginx`.

## STARTTLS ports and this certificate

Let's Encrypt/`certbot` here only issues **one** certificate, used by the
proxy's implicit-TLS ports. The STARTTLS ports (25, 587, 143, 110, 119,
5222, 5269) are raw TCP passthrough — see
[Configuration: STARTTLS backends](configuration.md#starttls-backends) for
how to share this same certificate with those backend services if you want
STARTTLS to offer real TLS on them too.
