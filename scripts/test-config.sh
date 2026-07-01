#!/usr/bin/env bash
# Validates the nginx configuration templates by rendering them and running
# `nginx -t` inside the built image, exactly like the real container would
# do at startup. Used by .github/workflows/ci.yml and safe to run locally:
#
#   docker buildx build -f docker/Dockerfile -t nginx-reverse-proxy-mail:test --load .
#   IMAGE=nginx-reverse-proxy-mail:test ./scripts/test-config.sh
set -euo pipefail

IMAGE="${IMAGE:-nginx-reverse-proxy-mail:test}"
TEST_DOMAIN="test.example.com"

echo "==> Testing nginx config in ${IMAGE}"

docker run --rm \
    --entrypoint /bin/sh \
    -e DOMAIN="${TEST_DOMAIN}" \
    -e EXTRA_DOMAINS="www.${TEST_DOMAIN}" \
    -e NGINX_WORKER_PROCESSES=1 \
    -e SMTP_BACKEND=127.0.0.1:2525 \
    -e SMTP_SUBMISSION_BACKEND=127.0.0.1:2526 \
    -e SMTPS_BACKEND=127.0.0.1:2527 \
    -e IMAP_BACKEND=127.0.0.1:2528 \
    -e IMAPS_BACKEND=127.0.0.1:2529 \
    -e POP3_BACKEND=127.0.0.1:2530 \
    -e POP3S_BACKEND=127.0.0.1:2531 \
    -e NNTP_BACKEND=127.0.0.1:2532 \
    -e NNTPS_BACKEND=127.0.0.1:2533 \
    -e XMPP_CLIENT_BACKEND=127.0.0.1:2534 \
    -e XMPPS_CLIENT_BACKEND=127.0.0.1:2535 \
    -e XMPP_SERVER_BACKEND=127.0.0.1:2536 \
    -e HTTP_BACKEND=127.0.0.1:2537 \
    -e HTTPS_BACKEND=127.0.0.1:2538 \
    -e ADMIN_HTTPS_BACKEND=127.0.0.1:2539 \
    -e CUSTOM_TCP_1_PORT=4040 \
    -e CUSTOM_TCP_1_BACKEND=127.0.0.1:2540 \
    -e CUSTOM_TCP_2_PORT=44337 \
    -e CUSTOM_TCP_2_BACKEND=127.0.0.1:2541 \
    "${IMAGE}" -c "
        set -e
        mkdir -p /etc/letsencrypt/live/${TEST_DOMAIN}
        openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
            -keyout /etc/letsencrypt/live/${TEST_DOMAIN}/privkey.pem \
            -out /etc/letsencrypt/live/${TEST_DOMAIN}/fullchain.pem \
            -subj '/CN=${TEST_DOMAIN}' >/dev/null 2>&1
        /usr/local/bin/entrypoint.sh nginx -t
    "

echo "==> nginx config OK"
