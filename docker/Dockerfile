# syntax=docker/dockerfile:1.7
#
# nginx built from source on debian:stable-slim, statically linked against a
# freshly built OpenSSL, with the modules required to reverse-proxy
# SMTP/IMAP/POP3/NNTP/XMPP (stream + mail) and HTTP/HTTPS (http).
#
# Version pins come from docker/NGINX_VERSION and docker/OPENSSL_VERSION so the
# scheduled-rebuild workflow can bump them automatically (see
# docs/release-process.md). They can also be overridden at build time:
#
#   docker buildx build \
#     --build-arg NGINX_VERSION=1.26.3 \
#     --build-arg OPENSSL_VERSION=3.4.0 \
#     -f docker/Dockerfile .
#
# Supported platforms: linux/amd64, linux/arm64, linux/arm/v7

ARG DEBIAN_BASE_TAG=stable-slim
ARG NGINX_VERSION=1.26.3
ARG OPENSSL_VERSION=3.4.0

########################################################################
# Stage 1: build nginx + OpenSSL from source
########################################################################
FROM debian:${DEBIAN_BASE_TAG} AS builder

ARG NGINX_VERSION
ARG OPENSSL_VERSION
# GPG fingerprints nginx.org uses to sign release tarballs.
ARG NGINX_GPG_KEYS="573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62 8540A6F18833A80E9C1653A42FD21310B49F6B46 9E9BE90EACBCDE69FE9B204CBCDCD8A38D88A2B3"

ENV DEBIAN_FRONTEND=noninteractive

# Build tooling + the dev headers nginx's ./configure links against for
# everything we do NOT compile from source ourselves (PCRE2, zlib). OpenSSL
# is compiled from source below so we control its version/patch level
# independently of whatever ships in debian:stable.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        gnupg \
        dirmngr \
        patch \
        libpcre2-dev \
        zlib1g-dev \
        perl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src

# Optional hotfix patches (e.g. a backported CVE fix ahead of the next
# upstream point release). Empty by default -- see docker/patches/README.md.
COPY docker/patches/ /usr/src/patches/

# --- Fetch + verify nginx source -------------------------------------------------
RUN curl -fsSL -o nginx.tar.gz "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" \
    && curl -fsSL -o nginx.tar.gz.asc "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz.asc" \
    && GNUPGHOME="$(mktemp -d)" \
    && export GNUPGHOME \
    && for key in ${NGINX_GPG_KEYS}; do \
         gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "${key}" \
           || gpg --batch --keyserver hkps://keyserver.ubuntu.com --recv-keys "${key}"; \
       done \
    && gpg --batch --verify nginx.tar.gz.asc nginx.tar.gz \
    && mkdir -p nginx \
    && tar -xzf nginx.tar.gz -C nginx --strip-components=1 \
    && gpgconf --kill dirmngr || true \
    && rm -rf "${GNUPGHOME}" nginx.tar.gz nginx.tar.gz.asc \
    && for p in /usr/src/patches/nginx/*.patch; do \
         [ -e "$p" ] || continue; \
         echo "Applying nginx patch: $p"; \
         patch -d nginx -p1 < "$p"; \
       done

# --- Fetch + verify OpenSSL source -----------------------------------------------
RUN curl -fsSL -o openssl.tar.gz "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz" \
    && curl -fsSL -o openssl.tar.gz.sha256 "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz.sha256" \
    && echo "$(cat openssl.tar.gz.sha256)  openssl.tar.gz" | sha256sum -c - \
    && mkdir -p openssl \
    && tar -xzf openssl.tar.gz -C openssl --strip-components=1 \
    && rm -f openssl.tar.gz openssl.tar.gz.sha256 \
    && for p in /usr/src/patches/openssl/*.patch; do \
         [ -e "$p" ] || continue; \
         echo "Applying openssl patch: $p"; \
         patch -d openssl -p1 < "$p"; \
       done

# --- Configure + compile ---------------------------------------------------------
# Module set covers:
#   http_ssl / http_v2       -> HTTPS + h2 for ports 443/8443
#   http_realip / http_gzip_static / http_stub_status / http_auth_request
#   stream / stream_ssl / stream_ssl_preread / stream_realip
#                             -> generic TCP+TLS proxying for the mail/XMPP/NNTP/custom ports
#   mail / mail_ssl           -> native IMAP/POP3/SMTP proxy building blocks
WORKDIR /usr/src/nginx
RUN ./configure \
        --prefix=/etc/nginx \
        --sbin-path=/usr/sbin/nginx \
        --modules-path=/usr/lib/nginx/modules \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --pid-path=/var/run/nginx.pid \
        --lock-path=/var/run/nginx.lock \
        --http-client-body-temp-path=/var/cache/nginx/client_temp \
        --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
        --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
        --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
        --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
        --user=nginx \
        --group=nginx \
        --with-compat \
        --with-file-aio \
        --with-threads \
        --with-http_ssl_module \
        --with-http_v2_module \
        --with-http_realip_module \
        --with-http_gzip_static_module \
        --with-http_stub_status_module \
        --with-http_auth_request_module \
        --with-http_sub_module \
        --with-http_secure_link_module \
        --with-stream \
        --with-stream_ssl_module \
        --with-stream_ssl_preread_module \
        --with-stream_realip_module \
        --with-mail \
        --with-mail_ssl_module \
        --with-openssl=/usr/src/openssl \
        --with-openssl-opt="no-weak-ssl-ciphers no-ssl3 no-shared" \
        --with-pcre-jit \
    && make -j"$(nproc)" \
    && make install DESTDIR=/build \
    && strip /build/usr/sbin/nginx

########################################################################
# Stage 2: minimal runtime image
########################################################################
FROM debian:${DEBIAN_BASE_TAG} AS final

LABEL org.opencontainers.image.title="nginx-reverse-proxy-mail" \
      org.opencontainers.image.description="nginx reverse proxy for SMTP/IMAP/POP3/NNTP/XMPP/HTTP(S) with Let's Encrypt" \
      org.opencontainers.image.source="https://github.com/opentreecz/nginx-reverse-proxy-mail" \
      org.opencontainers.image.licenses="MIT"

ARG NGINX_VERSION
ARG OPENSSL_VERSION
ENV NGINX_VERSION=${NGINX_VERSION} \
    OPENSSL_VERSION=${OPENSSL_VERSION} \
    DEBIAN_FRONTEND=noninteractive \
    NGINX_WORKER_PROCESSES=auto \
    NGINX_RELOAD_INTERVAL=12h

# Runtime deps: PCRE2/zlib shared libs (dynamically linked), ca-certificates
# for outbound TLS to backends, gettext-base for envsubst templating, tzdata
# so container logs reflect TZ, curl for the healthcheck.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libpcre2-8-0 \
        zlib1g \
        ca-certificates \
        gettext-base \
        tzdata \
        curl \
        openssl \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system --gid 101 nginx \
    && useradd --system --gid nginx --no-create-home --home-dir /nonexistent --comment "nginx user" --shell /usr/sbin/nologin --uid 101 nginx

COPY --from=builder /build/ /

RUN mkdir -p /var/cache/nginx/client_temp /var/cache/nginx/proxy_temp \
             /var/cache/nginx/fastcgi_temp /var/cache/nginx/uwsgi_temp /var/cache/nginx/scgi_temp \
             /var/www/certbot /etc/nginx/conf.d/http /etc/nginx/conf.d/stream \
    && chown -R nginx:nginx /var/cache/nginx /var/log/nginx /var/www/certbot \
    && rm -rf /etc/nginx/html /etc/nginx/*.default

COPY nginx/nginx.conf /etc/nginx/nginx.conf.template
COPY nginx/conf.d/http/ /etc/nginx/conf.d/http/
COPY nginx/conf.d/stream/ /etc/nginx/conf.d/stream/
COPY nginx/snippets/ /etc/nginx/snippets/
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY docker/reload-loop.sh /usr/local/bin/reload-loop.sh
COPY docker/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/reload-loop.sh /usr/local/bin/healthcheck.sh \
    && mv /etc/nginx/conf.d/http /etc/nginx/conf.d/http.templates \
    && mv /etc/nginx/conf.d/stream /etc/nginx/conf.d/stream.templates \
    && mv /etc/nginx/snippets /etc/nginx/snippets.templates

# 80/443/8443 http | 25/587/465/143/993/110/995 mail | 119/563 nntp |
# 5222/5223/5269 xmpp | 4040/44337 custom
EXPOSE 25 80 110 119 143 443 465 563 587 993 995 4040 5222 5223 5269 8443 44337

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ["/usr/local/bin/healthcheck.sh"]

STOPSIGNAL SIGQUIT

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
