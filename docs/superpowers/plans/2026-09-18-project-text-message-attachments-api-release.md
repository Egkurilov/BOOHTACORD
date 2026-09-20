# Project Text Message Attachments API Release Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish safe attachment metadata in text-message history through one unique non-`latest` API image, without restarting web, database, LiveKit, Caddy or storage services.

**Architecture:** No migration is required: the existing schema already has `attachments` and `message_attachments`. The production backend context is already compatible with the previous download leaf, so only the current list-history source overlay is transferred before building a new API image. Guest smoke proves the regular ingress; no authenticated data, attachment name or byte is accessed.

**Tech Stack:** Docker Compose, SSH, Go API, Caddy public ingress.

---

### Task 1: Validate a unique, API-only target

**Files:**
- Inspect: production API/web image identities
- Transfer: `backend/internal/chat/list_text_messages/service.go`, `postgres/attachments.go`, `postgres/repository.go`, `api/http_handler.go`

- [x] **Step 1: Generate an unused image tag and staging path.**

```powershell
$tag = "voice-platform-api:release-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$stage = "/tmp/voice-platform-api-$($tag.Split(':')[1])"
```

Require `docker image inspect $tag` to report absent and the private stage to be absent before creation. Record only API/web image tags, never `.env` contents.

- [x] **Step 2: Confirm no migration or mutable data operation belongs to the leaf.**

The change only reads existing columns and adds projection logic. Do not run `migrate`, touch database/storage volumes, create backups, or restart dependencies.

### Task 2: Build and recreate only API

**Files:**
- Modify remotely: the four exact list-history source files and `.env` `API_IMAGE` only

- [x] **Step 1: Copy only the exact leaf sources into a `0700` staging directory.**

```powershell
scp backend/internal/chat/list_text_messages/service.go "$target`:$stage/service.go"
scp backend/internal/chat/list_text_messages/postgres/attachments.go "$target`:$stage/attachments.go"
scp backend/internal/chat/list_text_messages/postgres/repository.go "$target`:$stage/repository.go"
scp backend/internal/chat/list_text_messages/api/http_handler.go "$target`:$stage/http_handler.go"
```

Do not copy local tests, docs, frontend, credentials, attachment bytes or unrelated dirty source.

- [x] **Step 2: Overlay the sources, build a unique image and replace `API_IMAGE`.**

```sh
sudo install -m 644 "$stage/service.go" backend/internal/chat/list_text_messages/service.go
sudo install -m 644 "$stage/attachments.go" backend/internal/chat/list_text_messages/postgres/attachments.go
sudo install -m 644 "$stage/repository.go" backend/internal/chat/list_text_messages/postgres/repository.go
sudo install -m 644 "$stage/http_handler.go" backend/internal/chat/list_text_messages/api/http_handler.go
sudo env API_IMAGE="$image" docker compose build api
sudo sed -i -E "s|^API_IMAGE=.*$|API_IMAGE=$image|" .env
```

Require a successful image build. Do not print `.env` or use `latest`.

- [x] **Step 3: Recreate API only and remove the exact staging path.**

```sh
sudo env API_IMAGE="$image" docker compose up -d --no-deps --no-build --force-recreate api
sudo docker compose ps api --format '{{.Name}} {{.Image}} {{.Status}}'
```

Require `Up`; the web tag must remain unchanged. Delete only the verified stage after the build/recreate succeeds.

### Task 3: Smoke without protected data

**Files:**
- Inspect: `https://v.bootybay.ru/`, `/health`, `/api/v1/auth/session`

- [x] **Step 1: Confirm public landing, health and guest session return HTTP 200.**

The session body must state `authenticated:false`; do not log in.

- [x] **Step 2: Confirm API/web identities and stage cleanup.**

The API must use the new tag, web must retain its current tag, and the exact staging path must be absent. This smoke does not prove participant history ACL, attachment metadata, browser rendering or download behavior.
