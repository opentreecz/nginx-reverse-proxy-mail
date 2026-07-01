#!/usr/bin/env bash
# Prints the latest stable nginx and OpenSSL 3.x release versions.
# Used by .github/workflows/scheduled-rebuild.yml to decide whether
# docker/NGINX_VERSION / docker/OPENSSL_VERSION need bumping.
#
# Usage:
#   ./scripts/check-latest-versions.sh nginx
#   ./scripts/check-latest-versions.sh openssl
set -euo pipefail

latest_nginx() {
    # nginx.org publishes tarballs for both the mainline and stable branches
    # under /download/. By convention the stable branch has an *even* minor
    # version (1.26.x, 1.28.x, ...); mainline has an odd one. Pick the
    # highest patch release among even-minor tarballs.
    curl -fsSL https://nginx.org/download/ \
        | grep -oE 'nginx-1\.[0-9]+\.[0-9]+\.tar\.gz' \
        | sed -E 's/nginx-(.*)\.tar\.gz/\1/' \
        | awk -F. '$2 % 2 == 0' \
        | sort -t. -k1,1n -k2,2n -k3,3n \
        | tail -n1
}

latest_openssl() {
    # Use the GitHub API tag list for openssl/openssl, restricted to
    # released 3.x versions (tags look like "openssl-3.4.0").
    curl -fsSL "https://api.github.com/repos/openssl/openssl/tags?per_page=100" \
        | grep -oE '"name": *"openssl-3\.[0-9]+\.[0-9]+"' \
        | grep -oE '3\.[0-9]+\.[0-9]+' \
        | sort -t. -k1,1n -k2,2n -k3,3n \
        | tail -n1
}

case "${1:-}" in
    nginx)   latest_nginx ;;
    openssl) latest_openssl ;;
    *) echo "usage: $0 {nginx|openssl}" >&2; exit 1 ;;
esac
