# Private Raster Attachment Preview Production Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish the ACL-gated raster preview API and its text-message UI using unique pinned local image tags without changing data schema or unrelated production services.

**Architecture:** The new API code invokes existing download ACL/persistence code and introduces no migration, so the host gets only `storage_routes.go` plus the two runtime preview files before rebuilding/recreating API. The web host receives only the preview URL helper and attachment renderer before rebuilding/recreating web. Caddy routes `/api/v1` to the existing API service, so it is not recreated. Guest smoke validates availability, route authentication and the public JS bundle; it cannot validate a real private preview without the owner-operated login/e2e TODO.

**Tech Stack:** Docker Compose, SSH, Go API image, Vue/Vite web image, Caddy public ingress.

---

### Task 1: Pin the precise release scope

**Files:**
- Transfer API: `backend/cmd/api/storage_routes.go`
- Transfer API: `backend/internal/storage/preview_text_attachment/service.go`
- Transfer API: `backend/internal/storage/preview_text_attachment/api/http_handler.go`
- Transfer web: `frontend/src/conversation/text_message_attachment_preview_url.ts`
- Transfer web: `frontend/src/conversation/TextMessageAttachments.vue`

- [x] **Step 1: Reconfirm local test/build evidence**

Run: `go test ./... && go vet ./...` from `backend`; `npm test -- --run && npm run build` from `frontend`.

Expected: all commands exit 0. Do not transfer test files, plans, source maps, `dist`, `node_modules`, contracts, `.env`, or credentials.

- [x] **Step 2: Generate unique non-`latest` tags and verify remote stage/image absence**

```powershell
$apiTag = "voice-platform-api:release-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$webTag = "voice-platform-web:release-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$stage = "/tmp/voice-platform-preview-$($apiTag.Split(':')[1])"
```

Require both tags and exact stage path to be absent. Inspect API/web Compose status and record tags only; never output `.env` values.

### Task 2: Build and recreate only API and web

**Files:**
- Modify remotely: five exact runtime source files above and `.env` `API_IMAGE`/`WEB_IMAGE` lines only

- [x] **Step 1: Copy only the five named runtime files into a `0700` staging directory**

```powershell
scp -i $sshKey backend/cmd/api/storage_routes.go "$target`:$stage/storage_routes.go"
scp -i $sshKey backend/internal/storage/preview_text_attachment/service.go "$target`:$stage/preview_service.go"
scp -i $sshKey frontend/src/conversation/TextMessageAttachments.vue "$target`:$stage/TextMessageAttachments.vue"
```

Copy the remaining two named files individually. Do not transfer directory trees or remove production files.

- [x] **Step 2: Overlay, build unique images, and update only two image variables**

```sh
sudo install -m 644 "$stage/storage_routes.go" backend/cmd/api/storage_routes.go
sudo install -m 644 "$stage/preview_service.go" backend/internal/storage/preview_text_attachment/service.go
sudo env API_IMAGE="$apiTag" WEB_IMAGE="$webTag" docker compose build api web
sudo sed -i -E "s|^API_IMAGE=.*$|API_IMAGE=$apiTag|; s|^WEB_IMAGE=.*$|WEB_IMAGE=$webTag|" .env
```

Install the remaining exact handler/helper/component paths. Require both `.env` keys to exist before replacement. Do not run `migrate`, alter volumes, restart PostgreSQL/LiveKit/Caddy, or touch `fluxer-edge`.

- [x] **Step 3: Recreate only API and web, then remove exactly the verified stage**

```sh
sudo env API_IMAGE="$apiTag" WEB_IMAGE="$webTag" docker compose up -d --no-deps --no-build --force-recreate api web
sudo docker compose ps api web --format '{{.Name}} {{.Image}} {{.Status}}'
sudo rm -rf -- "$stage"
```

Require both named containers to be `Up` on their new tags before cleanup. The deleted path must equal the pre-verified unique `/tmp/voice-platform-preview-...` directory.

### Task 3: Safe production smoke and record

**Files:**
- Inspect: `https://v.bootybay.ru/`
- Inspect: `https://v.bootybay.ru/api/v1/health`
- Inspect: `https://v.bootybay.ru/api/v1/auth/session`
- Inspect: unauthenticated `GET /api/v1/channels/{UUID}/attachments/{UUID}/preview`
- Modify: `docs/superpowers/plans/2026-09-18-private-raster-attachment-preview-production-release.md`

- [x] **Step 1: Verify public service health and preview route authentication**

```sh
curl -fsS -o /dev/null -w '%{http_code}\n' https://v.bootybay.ru/
curl -fsS https://v.bootybay.ru/api/v1/health
curl -fsS https://v.bootybay.ru/api/v1/auth/session
curl -sS -o /dev/null -w '%{http_code}\n' https://v.bootybay.ru/api/v1/channels/11111111-1111-4111-8111-111111111111/attachments/22222222-2222-4222-8222-222222222222/preview
```

Expected: landing 200, healthy JSON, guest `authenticated:false`, and preview 401. Do not log in, upload a file, call a private preview with owner credentials, or expose attachment content.

- [x] **Step 2: Confirm the live public bundle contains the preview affordance**

Read the script path from the public index and verify the JS bundle includes the Russian preview-alt text `Предпросмотр:`. This proves static delivery only, not authenticated rendering.

- [x] **Step 3: Record results and preserve shared worktree**

Confirm exact stage removal and both new image tags. Mark completed plan steps `[x]`, append the test/build, tags and smoke outcomes, inspect `git status --short` locally, and leave every change unstaged/uncommitted.

## Self-review

- **Scope:** This delivers one T-045 text-channel private raster-preview leaf. No API contract or source allows a public object URL, cross-channel fetch, source SVG/HTML render, or DM preview.
- **Rollback boundary:** Existing unique API/web tags remain available locally for an operator to select if rollback is required; this plan does not automate a rollback, change schema, or mutate data.
- **Evidence limit:** Guest smoke proves deployment and middleware registration only. The owner-operated authenticated test remains required for actual private preview rendering and still does not close POC/media gates.

## Execution evidence

- Local release preflight: `go test ./...`, `go vet ./...`, `scripts/verify-contracts.ps1`, `scripts/verify-spec-traceability.ps1`, and frontend `npm test -- --run && npm run build` all passed. Frontend: 49 files, 117 tests.
- Production release: transferred exactly five runtime files to a `0700` temporary directory; built and recreated only API as `voice-platform-api:release-20260918-221140` and web as `voice-platform-web:release-20260918-221140`.
- Scope: no migration, PostgreSQL, LiveKit, Caddy, persistent volume, `.env` value disclosure, or `fluxer-edge` action occurred. The exact temporary stage was removed after both containers were `Up`.
- Guest smoke: landing returned 200, health returned `{"status":"ok"}`, guest session returned `{"authenticated":false}`, and an unauthenticated preview request returned 401. The live `index-JX3eTD0x.js` bundle contains `Предпросмотр:`.
