#!/bin/sh
# Periodically reloads nginx so certificates renewed by the certbot sidecar
# are picked up without a container restart. Interval is configurable via
# NGINX_RELOAD_INTERVAL (understood by `sleep`, e.g. "12h", "45m").
set -eu

INTERVAL="${NGINX_RELOAD_INTERVAL:-12h}"

while true; do
    sleep "${INTERVAL}"
    if nginx -t >/dev/null 2>&1; then
        nginx -s reload
    fi
done
