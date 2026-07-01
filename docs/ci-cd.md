# CI/CD

Four workflows under `.github/workflows/`.

## `ci.yml` — every push and pull request

| Job | What it does |
|---|---|
| `lint` | `hadolint` on `docker/Dockerfile`, `shellcheck` on every shell script, `yamllint` on the compose file/workflows, `markdownlint` on the docs. |
| `compose-validate` | `docker compose config -q` against `.env.example` — catches YAML/interpolation mistakes without needing a real build. |
| `build-and-test` | Matrix over `linux/amd64`, `linux/arm64`, `linux/arm/v7`: builds the image with Buildx/QEMU. The `amd64` build is `--load`ed and then validated for real with `scripts/test-config.sh` (renders every template with dummy values and runs `nginx -t` inside the built image); `arm64`/`arm/v7` are build-only (cross-arch config testing under emulation is possible but slow, so CI trusts that identical config renders identically across arches and just confirms the image *builds*). |

All three must pass before merging.

## `release.yml` — on `vX.Y.Z` tags

Builds and publishes everything a release needs — see
[Release process](release-process.md) for the full artifact list.

## `scheduled-rebuild.yml` — every Monday

Two independent jobs — see
[Release process: staying current](release-process.md#staying-current).

## `docs.yml` — GitHub Pages

- **Trigger:** push to `main` touching `docs/**` or `mkdocs.yml`, plus
  manual dispatch.
- **Build:** `pip install -r docs/requirements.txt` then `mkdocs build
  --strict` — `--strict` fails the build on broken internal links or nav
  entries pointing at missing files, which is the validation step for the
  documentation.
- **Deploy:** the built `site/` directory is uploaded with
  `actions/upload-pages-artifact` and published with
  `actions/deploy-pages`.

One-time repo setting required: **Settings → Pages → Build and deployment →
Source: GitHub Actions**. After that, every merge to `main` that touches
docs redeploys `https://opentreecz.github.io/nginx-reverse-proxy-mail/`
automatically.

## Dependabot

`.github/dependabot.yml` watches three ecosystems weekly:

- `github-actions` (every workflow's `uses:` pins)
- `docker` in `/docker` (the `debian:stable-slim` base image tag)
- `pip` in `/docs` (`mkdocs`/`mkdocs-material` pins in `docs/requirements.txt`)

nginx/OpenSSL themselves are intentionally *not* Dependabot-managed — they're
version-pinned in `docker/NGINX_VERSION`/`docker/OPENSSL_VERSION` and kept
current by `scheduled-rebuild.yml` instead, which understands nginx's
stable-vs-mainline branching (Dependabot's Docker ecosystem update logic
does not).
