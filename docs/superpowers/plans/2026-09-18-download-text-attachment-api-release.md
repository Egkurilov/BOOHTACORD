# Download Text Attachment API Release Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish the validated authenticated text-attachment download endpoint as one unique non-`latest` API image, without changing the web, database, LiveKit, proxy or persistent storage services.

**Architecture:** The change has no schema migration. A new API image is built from the scoped backend source on the production host, its tag alone replaces `API_IMAGE`, and Compose recreates only `api` without dependencies. Public health and guest-session smoke prove the ingress remains live; an unauthenticated attachment request proves the new path stays behind session middleware, not that a real participant download ACL has passed.

**Tech Stack:** Docker Compose, SSH, Go API, Caddy public ingress.

---

### Task 1: Confirm an isolated release target

**Files:**
- Inspect: `/opt/voice-platform/compose.yaml` and `.env` on the production host
- Inspect: the deployed backend build context plus the exact new route and storage leaf

- [x] **Step 1: Choose one unused API image tag and private staging directory.**

```powershell
$tag = "voice-platform-api:release-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$stage = "/tmp/voice-platform-api-$($tag.Split(':')[1])"
```

Confirm the tag does not exist remotely. Confirm `docker compose ps api web` identifies the currently running API and web images before any change.

- [x] **Step 2: Verify that no database migration is part of this leaf.**

The API reads the existing `attachments`, `message_attachments` and `messages` columns only. Do not invoke `migrate`, modify persistent volumes, run `pg_dump`, or restart PostgreSQL, LiveKit, Caddy or web.

### Task 2: Build and replace only the API container

**Files:**
- Transfer: `backend/cmd/api/storage_routes.go`, `backend/internal/storage/download_text_attachment/`
- Modify remotely: only those two source paths and the `API_IMAGE` value in `/opt/voice-platform/.env`

- [x] **Step 1: Transfer the validated backend build inputs to the private staging directory.**

```powershell
scp backend/cmd/api/storage_routes.go "$target`:$stage/storage_routes.go"
scp -r backend/internal/storage/download_text_attachment "$target`:$stage/download_text_attachment"
```

The stage is mode `0700`; do not transfer `.env`, database files, attachment bytes, logs, credentials, or unrelated dirty source files. The production host retains the already-deployed compatible backend context and receives only this leaf's overlay.

- [x] **Step 2: Build a unique API image and update the explicit image tag.**

```sh
sudo env API_IMAGE="$image" docker compose build api
sudo sed -i -E "s|^API_IMAGE=.*$|API_IMAGE=$image|" .env
```

The build must pass its Go test/build stage. Do not use `latest` and do not print `.env`.

- [x] **Step 3: Recreate API only and remove the verified staging directory.**

```sh
sudo env API_IMAGE="$image" docker compose up -d --no-deps --no-build --force-recreate api
sudo docker compose ps api --format '{{.Name}} {{.Image}} {{.Status}}'
```

Require `Up`; keep the previous image available locally for a compatible rollback. Delete only the exact verified `/tmp/voice-platform-api-...` stage after a successful build.

### Task 3: Smoke the public boundary without credentials or content

**Files:**
- Inspect: `https://v.bootybay.ru/`, `/health`, `/api/v1/auth/session`, and the new attachment route

- [x] **Step 1: Confirm public landing, health and guest session return HTTP 200.**

```powershell
Invoke-WebRequest https://v.bootybay.ru/
Invoke-WebRequest https://v.bootybay.ru/health
Invoke-WebRequest https://v.bootybay.ru/api/v1/auth/session
```

The session response must state `authenticated:false`; no login is performed.

- [x] **Step 2: Confirm the new route rejects an unauthenticated request with HTTP 401.**

```powershell
Invoke-WebRequest https://v.bootybay.ru/api/v1/channels/00000000-0000-4000-8000-000000000001/attachments/00000000-0000-4000-8000-000000000002
```

Do not treat this as proof of current-channel ACL, file download, filename safety or participant access; those require an authenticated integration run with benign test data.

- [x] **Step 3: Recheck service image identities and staging cleanup.**

Require API to report the new tag, web to retain its prior tag, and the exact remote staging directory to be absent. Do not stage or commit the dirty local worktree.
