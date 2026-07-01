#!/usr/bin/env bash
# shellcheck disable=SC1091  # .env is a generated/local file, not present at lint time
# One-time bootstrap for the Let's Encrypt certificate used by every TLS
# server block in this proxy (443, 8443, 465, 993, 995, 563, 5223).
#
# nginx refuses to start if the certificate files referenced in
# nginx/snippets/ssl-params.conf.template don't exist yet, and certbot can't
# issue a certificate until nginx is serving the ACME HTTP-01 challenge on
# port 80 -- so this script breaks the chicken-and-egg problem the standard
# way: create a throwaway self-signed cert, start nginx, request the real
# certificate over the webroot challenge, then reload nginx with it.
#
# Usage: ./scripts/init-letsencrypt.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

if [ ! -f .env ]; then
    echo "Missing .env - copy .env.example to .env and edit it first." >&2
    exit 1
fi

set -a; source .env; set +a

: "${DOMAIN:?DOMAIN must be set in .env}"
: "${LETSENCRYPT_EMAIL:?LETSENCRYPT_EMAIL must be set in .env}"
EXTRA_DOMAINS="${EXTRA_DOMAINS:-}"
STAGING="${LETSENCRYPT_STAGING:-0}"

ALL_DOMAINS="${DOMAIN} ${EXTRA_DOMAINS}"
DOMAIN_ARGS=()
for d in ${ALL_DOMAINS}; do
    DOMAIN_ARGS+=(-d "${d}")
done

CERTBOT_CONF_DIR="./data/certbot/conf"
CERTBOT_WWW_DIR="./data/certbot/www"
LIVE_DIR="${CERTBOT_CONF_DIR}/live/${DOMAIN}"

mkdir -p "${CERTBOT_CONF_DIR}" "${CERTBOT_WWW_DIR}"

if [ -d "${LIVE_DIR}" ]; then
    read -r -p "Existing certificate data found for ${DOMAIN}. Re-request anyway? [y/N] " decision
    case "${decision}" in
        [yY]*) ;;
        *) echo "Aborting, existing certificate left untouched."; exit 0 ;;
    esac
fi

echo "==> Creating a temporary self-signed certificate so nginx can start..."
mkdir -p "${LIVE_DIR}"
openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
    -keyout "${LIVE_DIR}/privkey.pem" \
    -out "${LIVE_DIR}/fullchain.pem" \
    -subj "/CN=${DOMAIN}" >/dev/null 2>&1

echo "==> Starting nginx with the temporary certificate..."
docker compose up -d nginx

echo "==> Removing the temporary certificate..."
rm -rf "${CERTBOT_CONF_DIR}/live" "${CERTBOT_CONF_DIR}/archive" "${CERTBOT_CONF_DIR}/renewal"

STAGING_ARG=""
if [ "${STAGING}" = "1" ]; then
    echo "==> LETSENCRYPT_STAGING=1: using the Let's Encrypt staging endpoint."
    STAGING_ARG="--staging"
fi

echo "==> Requesting the real certificate from Let's Encrypt for: ${ALL_DOMAINS}"
docker compose run --rm --entrypoint certbot certbot certonly \
    --webroot -w /var/www/certbot \
    "${DOMAIN_ARGS[@]}" \
    --email "${LETSENCRYPT_EMAIL}" \
    --rsa-key-size 4096 \
    --agree-tos \
    --no-eff-email \
    --non-interactive \
    ${STAGING_ARG}

echo "==> Reloading nginx with the issued certificate..."
docker compose exec nginx nginx -s reload

echo "==> Done. Certificates live under ${CERTBOT_CONF_DIR}/live/${DOMAIN}/"
echo "    The certbot sidecar (docker-compose.yml) will renew them automatically."
