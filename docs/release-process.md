# Release process

## Cutting a release

1. Merge whatever should go into the release into `main` (including any
   automated version-bump PR from `scheduled-rebuild.yml`).
2. Update `CHANGELOG.md`'s `[Unreleased]` section into a new `[X.Y.Z]`
   entry.
3. Tag and push:

   ```bash
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```

Pushing a `vX.Y.Z` tag triggers `.github/workflows/release.yml`, which
needs no further input — it reads `docker/NGINX_VERSION` and
`docker/OPENSSL_VERSION` from the tagged commit and builds from there.

## What gets published

| Artifact | Where |
|---|---|
| Multi-arch Docker image (`amd64`/`arm64`/`arm/v7`), tagged `X.Y.Z`, `X.Y`, `X`, and `latest` | `ghcr.io/opentreecz/nginx-reverse-proxy-mail` |
| Cosign keyless signature over the pushed image digest | attached to the GHCR image (verify with `cosign verify`) |
| `nginx-config-X.Y.Z.tar.gz` (the `nginx/` config tree + `docker-compose.yml` + `.env.example`) | GitHub Release assets |
| `docker-compose-X.Y.Z.yml` (standalone copy) | GitHub Release assets |
| `sbom-X.Y.Z.spdx.json` (SPDX SBOM of the image) | GitHub Release assets |
| Auto-generated release notes (commits since the previous tag) | GitHub Release body |

### Verifying the image signature

```bash
cosign verify \
  --certificate-identity-regexp 'https://github.com/opentreecz/nginx-reverse-proxy-mail/.github/workflows/release.yml@.*' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  ghcr.io/opentreecz/nginx-reverse-proxy-mail:X.Y.Z
```

### Consuming a release without building anything

```bash
mkdir deploy && cd deploy
curl -LO https://github.com/opentreecz/nginx-reverse-proxy-mail/releases/download/vX.Y.Z/nginx-config-X.Y.Z.tar.gz
tar xzf nginx-config-X.Y.Z.tar.gz --strip-components=1
cp .env.example .env && $EDITOR .env
# docker-compose.yml already references ghcr.io/opentreecz/nginx-reverse-proxy-mail:latest;
# pin it to :X.Y.Z if you want an immutable deployment.
./scripts/init-letsencrypt.sh
docker compose up -d
```

## Re-running a release

`release.yml` also accepts `workflow_dispatch` with an existing tag (`tag`
input) — use this to re-publish a release (e.g. after fixing a workflow bug)
without creating a new tag.

## Staying current

Two mechanisms, both in `.github/workflows/scheduled-rebuild.yml`, running
every Monday:

1. **Version bump PRs.** `scripts/check-latest-versions.sh` checks
   `nginx.org` for the newest *stable* (even minor version, e.g. `1.26.x`,
   `1.28.x`) nginx release and the GitHub API for the newest `openssl-3.x.y`
   tag. If either is newer than `docker/NGINX_VERSION` /
   `docker/OPENSSL_VERSION`, a PR is opened automatically. Merging it (and
   tagging a release) is what actually ships the new version — the
   scheduled job itself never pushes to `main` or tags anything.
2. **Nightly rebuilds.** Regardless of whether nginx/OpenSSL changed, the
   image is rebuilt weekly with `--no-cache` and a fresh `debian:stable-slim`
   pull, so it always carries current Debian security patches, and pushed
   as the mutable `ghcr.io/opentreecz/nginx-reverse-proxy-mail:nightly` tag.
   This tag is **not** a release — it's not signed, has no SBOM, and isn't
   attached to a GitHub Release — it exists purely so a base-image-only CVE
   fix doesn't have to wait for a nginx/OpenSSL version bump to reach an
   image you can pull.

If you need the base image refreshed in an actual **release**, cut one the
normal way (tag `vX.Y.Z`) — `release.yml` always builds `FROM
debian:stable-slim` fresh (no cache from the nightly job), so every tagged
release also carries whatever Debian security patches exist at build time.
