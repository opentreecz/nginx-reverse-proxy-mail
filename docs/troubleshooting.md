# Troubleshooting

## `nginx` container exits immediately on first run

**Symptom:** `docker compose up -d` starts and immediately stops the
`nginx` service; `docker compose logs nginx` shows an `nginx: [emerg]
cannot load certificate ...` error.

**Cause:** the certificate files under `/etc/letsencrypt/live/$DOMAIN/`
don't exist yet.

**Fix:** run `./scripts/init-letsencrypt.sh` before `docker compose up -d`
the first time — see [Let's Encrypt: first-time issuance](letsencrypt.md#first-time-issuance).

## `certbot` fails with "Timeout during connect" / rate limit errors

**Cause (timeout):** port 80 isn't reachable from the internet — a
firewall/security group is blocking it, another process already has it
bound, or DNS for `DOMAIN`/`EXTRA_DOMAINS` doesn't point here yet.

**Cause (rate limit):** too many issuance attempts against the production
endpoint. Set `LETSENCRYPT_STAGING=1` in `.env` while debugging (see
[Let's Encrypt: staging vs production](letsencrypt.md#staging-vs-production)),
then switch back once the flow works end-to-end.

## `nginx -t` fails after editing a template

Run it exactly the way CI does, against the real built image, before
restarting the real service:

```bash
docker buildx build -f docker/Dockerfile -t nginx-reverse-proxy-mail:local --load .
IMAGE=nginx-reverse-proxy-mail:local ./scripts/test-config.sh
```

The error message includes the rendered file path
(`/etc/nginx/conf.d/...`), not the `.template` source — open the matching
`*.template` file under `nginx/conf.d/` or `nginx/snippets/`.

## A backend connection works locally but not through the proxy

- Confirm the `*_BACKEND` value in `.env` is reachable **from the `nginx`
  container**, not just from the host: `docker compose exec nginx sh -c
  "echo | timeout 2 nc -v <host> <port>"` (BusyBox `nc` if using a slim
  backend image — adjust as needed).
- If the backend is another Compose service, confirm both it and `nginx`
  are on the `proxy-net` network (see [Configuration](configuration.md#pointing-at-your-backends)).
- For STARTTLS ports (25/587/143/110/119/5222/5269), remember nginx forwards
  raw TCP — a backend that rejects plaintext connections outright (rather
  than offering STARTTLS) needs its own fix, not a proxy-side one.

## Renewed certificate isn't being used

nginx only picks up a renewed certificate on reload. Confirm the reload
loop is running (`docker compose exec nginx pgrep -fa reload-loop.sh`) and
check `NGINX_RELOAD_INTERVAL` in `.env` — or force it immediately:

```bash
docker compose exec nginx nginx -s reload
```

## Multi-arch build fails only on `arm/v7`

`arm/v7` (32-bit) builds run under QEMU emulation and are the slowest/most
memory-constrained of the three targets. If it fails with what looks like
an out-of-memory error during OpenSSL/nginx compilation, re-run the job —
GitHub-hosted runners occasionally hit transient memory pressure under
heavy emulation. A build that fails deterministically (not just under CI
load) usually means a genuine toolchain issue on 32-bit ARM worth filing an
issue for.

## CI `lint` job fails on a file you didn't touch

`yamllint`/`markdownlint`/`shellcheck` run over the whole repo, not just
your diff — a pre-existing violation in an unrelated file will still fail
your PR. Fix it as part of the same PR (small, self-contained lint fixes
are always welcome) rather than working around it.
