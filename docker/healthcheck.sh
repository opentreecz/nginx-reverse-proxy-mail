#!/bin/sh
# Used by the Docker HEALTHCHECK instruction. Hits the unauthenticated
# /healthz location exposed on port 80 (see nginx/conf.d/http/00-acme.conf.template)
# which is served locally regardless of the HTTPS redirect rule.
set -eu

exec curl -fsS --max-time 3 "http://127.0.0.1:80/healthz" -o /dev/null
