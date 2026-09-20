# GitVerse source deployment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On each trusted push to `master`, GitVerse Actions verifies the Go and Vue applications, transfers an exact source archive to the already-authorized deployment host, builds API and web images tagged by the immutable Git commit SHA, and performs the guarded maintenance/migrate/health release.

**Architecture:** The server keeps `/opt/voice-platform/.env` as the only persistent secret input. Each workflow creates a distinct `/opt/voice-platform-releases/<commit-sha>` source directory, copies only that existing `.env`, builds local non-`latest` images, and invokes the existing release guard against that directory; PostgreSQL, attachments, LiveKit and Caddy volumes retain the Compose project name `voice-platform`. The workflow uses the repository public key only to verify its private-key secret, pins the verified server host key, and never runs `ssh-keyscan`.

**Tech Stack:** GitVerse Actions YAML, Bash, OpenSSH, tar, Docker Compose, Go, Node.js/Vite.

---

### Task 1: Extend the release guard for commit-addressed local images

**Files:**
- Modify: `scripts/deploy-images.test.sh`
- Create: `scripts/deploy-local-images.test.sh`
- Modify: `scripts/deploy-images.sh`

- [x] **Step 1: Add a failing local-build path to the script test.**

```bash
API_IMAGE=voice-platform-api:0123456789abcdef0123456789abcdef01234567 \
WEB_IMAGE=voice-platform-web:0123456789abcdef0123456789abcdef01234567 \
bash scripts/deploy-images.sh
# Require local docker image inspection and assert that docker compose pull is absent.
```

- [x] **Step 2: Implement strict dual image modes.**

The guard accepts either two registry digest references or the exact pair `voice-platform-api:<40 lowercase hex>` and `voice-platform-web:<the same SHA>`. It rejects mixed modes, mismatched revisions, `latest`, missing local images and arbitrary tags. Digest mode retains `docker compose pull`; local-build mode inspects the two locally built images and never pulls.

- [x] **Step 3: Run the release-guard regression.**

Run: `bash scripts/deploy-images.test.sh`; `bash scripts/deploy-local-images.test.sh`

Expected: `deploy-images tests passed`.

### Task 2: Create a verified GitVerse Actions deployment workflow

**Files:**
- Create: `.gitverse/workflows/deploy-production.yaml`

- [x] **Step 1: Define trusted triggers and validation jobs.**

```yaml
on:
  push:
    branches: [master]
  workflow_dispatch:
```

Run `go test ./...`, `go vet ./...`, frontend `npm ci`, `npm test` and `npm run build` before deployment. Put the deploy job behind successful validation and a production concurrency group that does not cancel a running release.

- [x] **Step 2: Configure verified SSH without logging a key.**

```bash
printf '%s\n' "$DEPLOY_SSH_PRIVATE_KEY" > ~/.ssh/id_ed25519
test "$(ssh-keygen -y -f ~/.ssh/id_ed25519)" = "$(printf '%s' "$DEPLOY_SSH_PUB_KEY" | tr -d '\r\n')"
```

Use `secrets.DEPLOY_SSH_PRIVATE_KEY`, `vars.DEPLOY_SSH_PUB_KEY`, `vars.SSH_USER` and `vars.DEPLOY_SERVER_IP`. Store the reviewed ED25519 host key in the workflow `known_hosts`; every `ssh`/`scp` command uses `BatchMode=yes` and `StrictHostKeyChecking=yes`.

- [x] **Step 3: Transfer, build and release the exact checkout.**

```bash
git_sha="$(git rev-parse HEAD)"
tar --exclude-vcs --exclude=.env --exclude=frontend/node_modules -czf release.tgz .
```

Verify the archive SHA-256 after transfer, extract it into `/opt/voice-platform-releases/$git_sha`, copy the server-local `.env` with mode `0600`, build `voice-platform-api:$git_sha` and `voice-platform-web:$git_sha`, then run `scripts/deploy-images.sh` with `VOICE_PLATFORM_DIR` set to that release directory. Do not modify `/opt/voice-platform/.env`, delete volumes, use `latest`, print `.env`, or deploy from pull requests.

### Task 3: Document the operational boundary and validate the change

**Files:**
- Modify: `docs/ADMIN_OPERATIONS.md`
- Modify: `README.md`

- [x] **Step 1: Replace the obsolete GitHub/GHCR setup text with GitVerse details.**

Document the exact variables/secrets, the pinned host-key policy, source archive verification, commit-tag image rule, release directory retention, and the fact that adding a public key alone cannot authenticate a runner.

- [x] **Step 2: Run native checks.**

Run: `bash scripts/deploy-images.test.sh`; `bash scripts/deploy-local-images.test.sh`; `pwsh -NoProfile -File scripts/verify-contracts.ps1`; `pwsh -NoProfile -File scripts/verify-spec-traceability.ps1`; `docker compose --env-file .env.example -f compose.yaml config --quiet`; `git diff --check`.

Expected: all commands exit 0.

- [ ] **Step 3: Commit and push to `master`.**

Commit only workflow, release guard, release-guard test and documentation. The push itself is the first automatic GitVerse deployment candidate; report its CI status separately from static validation.
