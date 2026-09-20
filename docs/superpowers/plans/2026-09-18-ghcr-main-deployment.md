# GHCR Main Deployment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a trusted `main` push publish immutable API and web image digests to GHCR, deploy those exact digests over SSH, run migrations as a separate step, and smoke-test HTTPS.

**Architecture:** Existing PR and main tests remain read-only. A `publish` job runs only for a push to `main`, pushes two images tagged by commit SHA, and exposes their digest-qualified GHCR references. A `deploy` job transfers only Compose/Caddy/deploy-script files via verified SSH, then invokes a server-side script that persists digest references, pulls without building, migrates, restarts API/web/proxy, and checks the public health endpoint.

**Tech Stack:** GitHub Actions, GHCR, Docker Buildx, Docker Compose, Bash, SSH.

---

### Task 1: Add a fail-closed release deployment script

**Files:**
- Create: `scripts/deploy-images.sh`
- Test: `scripts/deploy-images.sh`

- [ ] **Step 1: Write the deployment guard script**

Require `API_IMAGE` and `WEB_IMAGE`; reject either when it ends in `:latest`, is not digest-qualified with `@sha256:`, or lacks a registry path. Require `/opt/voice-platform/.env` and a nonempty `PUBLIC_HOST` parsed from that file. No script path may print `.env` content or source it as shell code.

- [ ] **Step 2: Validate syntax and the no-latest guard**

Run:

```bash
bash -n scripts/deploy-images.sh
API_IMAGE=voice-platform-api:latest WEB_IMAGE=voice-platform-web:latest bash scripts/deploy-images.sh
```

Expected: syntax succeeds; the guarded run fails before Docker or `.env` mutation.

- [ ] **Step 3: Implement the ordered server release**

Use the following sequence only after guard validation:

```bash
docker compose --project-directory /opt/voice-platform -f /opt/voice-platform/compose.yaml pull api migrate web
docker compose --project-directory /opt/voice-platform -f /opt/voice-platform/compose.yaml run --rm --no-deps migrate
docker compose --project-directory /opt/voice-platform -f /opt/voice-platform/compose.yaml up -d --no-deps --no-build api web proxy
curl -fsS --retry 5 --retry-connrefused "https://${public_host}/api/v1/health"
```

Persist only the validated API/web digest references in `.env` with owner-only temporary-file permissions. Do not run `down`, volume deletion, backups or a down migration.

### Task 2: Publish immutable images after trusted checks

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Add a main-push-only publish job**

Add `publish` with:

```yaml
if: github.event_name == 'push' && github.ref == 'refs/heads/main'
needs: [contracts, backend, frontend]
permissions:
  contents: read
  packages: write
```

Log into `ghcr.io` with `${{ github.actor }}` and `${{ secrets.GITHUB_TOKEN }}`, then build/push `backend` and `frontend` with tags `ghcr.io/${{ github.repository_owner }}/voice-platform-api:${{ github.sha }}` and `ghcr.io/${{ github.repository_owner }}/voice-platform-web:${{ github.sha }}`.

- [ ] **Step 2: Expose digest-qualified workflow outputs**

Set `api_image` and `web_image` outputs to the corresponding `ghcr.io/...@${{ steps.<image>.outputs.digest }}` strings. The deploy job consumes these output values, never `latest` or a mutable SHA tag.

### Task 3: Deploy trusted images through verified SSH

**Files:**
- Modify: `.github/workflows/ci.yml`
- Modify: `docs/ADMIN_OPERATIONS.md`

- [ ] **Step 1: Add a deploy job that cannot run for PRs**

Use `needs: publish` and receive host, user, private key and known hosts only from `DEPLOY_HOST`, `DEPLOY_USER`, `DEPLOY_SSH_PRIVATE_KEY`, and `DEPLOY_KNOWN_HOSTS` secrets. Configure `StrictHostKeyChecking=yes`; do not use `ssh-keyscan` or accept a host key dynamically.

- [ ] **Step 2: Transfer a bounded release payload**

Copy only `compose.yaml`, `docker/Caddyfile` and `scripts/deploy-images.sh` into a server-created temporary directory. Install files with read-only modes for Compose/Caddy and `0755` for the script, then run `sudo API_IMAGE=<digest> WEB_IMAGE=<digest> /opt/voice-platform/scripts/deploy-images.sh`.

- [ ] **Step 3: Document the required deployment inputs**

List the four GitHub repository secrets, the required server GHCR pull permission and the fact that no successful CI/deploy evidence exists until a configured repository executes a trusted `main` run.

- [ ] **Step 4: Run local static checks**

Run:

```powershell
bash -n scripts/deploy-images.sh
./scripts/verify-compose-images.ps1
docker compose --env-file .env.example -f compose.yaml --profile operator config --quiet
git diff --check -- .github/workflows/ci.yml scripts/deploy-images.sh docs/ADMIN_OPERATIONS.md
```

Expected: local syntax/config checks pass. GitHub Actions and a remote GHCR digest deployment remain `NOT_RUN` until repository and secrets are supplied.
