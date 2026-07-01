# Ports & protocols

All 17 ports requested for this proxy, what they're for, how nginx handles
them, and which `.env` variable(s) point at the real backend.

| Port | Protocol | TLS | nginx handling | Config file | Backend variable(s) |
|------|----------|-----|-----------------|--------------|----------------------|
| 80 | HTTP | none | ACME HTTP-01 challenge + `/healthz` + redirect to 443 | `nginx/conf.d/http/00-acme-http.conf.template` | — |
| 443 | HTTPS | implicit, terminated | reverse proxy | `nginx/conf.d/http/10-https-main.conf.template` | `HTTPS_BACKEND` |
| 8443 | HTTPS (admin/alt) | implicit, terminated | reverse proxy | `nginx/conf.d/http/20-https-admin.conf.template` | `ADMIN_HTTPS_BACKEND` |
| 25 | SMTP (MTA-to-MTA) | STARTTLS | TCP passthrough | `nginx/conf.d/stream/10-smtp.conf.template` | `SMTP_BACKEND` |
| 587 | SMTP submission | STARTTLS | TCP passthrough | `nginx/conf.d/stream/10-smtp.conf.template` | `SMTP_SUBMISSION_BACKEND` |
| 465 | SMTPS | implicit, terminated | TLS-terminating proxy | `nginx/conf.d/stream/10-smtp.conf.template` | `SMTPS_BACKEND` |
| 143 | IMAP | STARTTLS | TCP passthrough | `nginx/conf.d/stream/20-imap.conf.template` | `IMAP_BACKEND` |
| 993 | IMAPS | implicit, terminated | TLS-terminating proxy | `nginx/conf.d/stream/20-imap.conf.template` | `IMAPS_BACKEND` |
| 110 | POP3 | STARTTLS | TCP passthrough | `nginx/conf.d/stream/30-pop3.conf.template` | `POP3_BACKEND` |
| 995 | POP3S | implicit, terminated | TLS-terminating proxy | `nginx/conf.d/stream/30-pop3.conf.template` | `POP3S_BACKEND` |
| 119 | NNTP (Usenet) | STARTTLS | TCP passthrough | `nginx/conf.d/stream/40-nntp.conf.template` | `NNTP_BACKEND` |
| 563 | NNTPS | implicit, terminated | TLS-terminating proxy | `nginx/conf.d/stream/40-nntp.conf.template` | `NNTPS_BACKEND` |
| 5222 | XMPP client-to-server | STARTTLS | TCP passthrough | `nginx/conf.d/stream/50-xmpp.conf.template` | `XMPP_CLIENT_BACKEND` |
| 5223 | XMPP client (legacy TLS) | implicit, terminated | TLS-terminating proxy | `nginx/conf.d/stream/50-xmpp.conf.template` | `XMPPS_CLIENT_BACKEND` |
| 5269 | XMPP server-to-server | STARTTLS | TCP passthrough | `nginx/conf.d/stream/50-xmpp.conf.template` | `XMPP_SERVER_BACKEND` |
| 4040 | custom TCP/HTTP | as-is | TCP passthrough | `nginx/conf.d/stream/60-custom.conf.template` | `CUSTOM_TCP_1_BACKEND` (port via `CUSTOM_TCP_1_PORT`) |
| 44337 | custom TCP/HTTP | as-is | TCP passthrough | `nginx/conf.d/stream/60-custom.conf.template` | `CUSTOM_TCP_2_BACKEND` (port via `CUSTOM_TCP_2_PORT`) |

## Notes

- **4040 and 44337** are not standard protocol ports for any of the
  services listed in the project brief. They're wired up as generic TCP
  passthrough slots (works for raw TCP or HTTP) so you can point them at
  whatever actually needs to live there (a webmail admin API, a chat
  federation port, a metrics endpoint, etc.) without touching the image —
  just change `CUSTOM_TCP_1_BACKEND` / `CUSTOM_TCP_2_BACKEND` in `.env`, or
  edit `nginx/conf.d/stream/60-custom.conf.template` if you need more than
  two.
- **"STARTTLS" rows are plaintext-in, plaintext-out** at this proxy — see
  [Architecture: TLS termination model](architecture.md#tls-termination-model)
  for why, and [Configuration](configuration.md#starttls-backends) for how
  to still get TLS on those ports.
- Every "implicit, terminated" row uses the **same** certificate
  (`/etc/letsencrypt/live/$DOMAIN/`), so one Let's Encrypt cert with
  `DOMAIN` + `EXTRA_DOMAINS` as SANs covers all of them.
- Outbound/backend traffic is plaintext on the Docker network created by
  `docker-compose.yml` (`proxy-net`). Put real backends on that same network
  (or route to them by IP/hostname reachable from the `nginx` container) —
  see [Configuration](configuration.md).
