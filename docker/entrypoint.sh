#!/bin/sh
# Renders the *.template config files shipped in the image into their real
# locations using envsubst, restricted to a known variable allow-list so we
# never accidentally touch nginx's own "$host"-style runtime variables, then
# execs the real command (normally `nginx -g "daemon off;"`).
set -eu

# shellcheck disable=SC2016  # intentionally literal: this is the envsubst allow-list, not a shell expansion
TEMPLATE_VARS='${DOMAIN} ${EXTRA_DOMAINS}
${SMTP_BACKEND} ${SMTP_SUBMISSION_BACKEND} ${SMTPS_BACKEND}
${IMAP_BACKEND} ${IMAPS_BACKEND}
${POP3_BACKEND} ${POP3S_BACKEND}
${NNTP_BACKEND} ${NNTPS_BACKEND}
${XMPP_CLIENT_BACKEND} ${XMPPS_CLIENT_BACKEND} ${XMPP_SERVER_BACKEND}
${HTTP_BACKEND} ${HTTPS_BACKEND} ${ADMIN_HTTPS_BACKEND}
${CUSTOM_TCP_1_PORT} ${CUSTOM_TCP_1_BACKEND}
${CUSTOM_TCP_2_PORT} ${CUSTOM_TCP_2_BACKEND}
${NGINX_WORKER_PROCESSES}'

render_dir() {
    src_dir="$1"
    dst_dir="$2"
    [ -d "${src_dir}" ] || return 0
    mkdir -p "${dst_dir}"
    for tpl in "${src_dir}"/*.template; do
        [ -e "${tpl}" ] || continue
        name="$(basename "${tpl}" .template)"
        envsubst "${TEMPLATE_VARS}" < "${tpl}" > "${dst_dir}/${name}"
    done
}

render_file() {
    src="$1"
    dst="$2"
    [ -e "${src}" ] || return 0
    envsubst "${TEMPLATE_VARS}" < "${src}" > "${dst}"
}

render_file /etc/nginx/nginx.conf.template /etc/nginx/nginx.conf
render_dir /etc/nginx/conf.d/http.templates /etc/nginx/conf.d/http
render_dir /etc/nginx/conf.d/stream.templates /etc/nginx/conf.d/stream
render_dir /etc/nginx/snippets.templates /etc/nginx/snippets

nginx -t

# Background loop that reloads nginx periodically so renewed Let's Encrypt
# certificates (written by the certbot sidecar to a shared volume) get
# picked up without needing to restart this container.
/usr/local/bin/reload-loop.sh &

exec "$@"
