# Text-message attachment picker web release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish the tested browser picker in one uniquely tagged web image while keeping API, data services, media services, proxy configuration, and persistent volumes unchanged.

**Architecture:** The Go API upload endpoint and text-message `attachment_ids` contract are already deployed, so this release transfers only the seven frontend runtime files required by the picker and builds `web` on the host. Compose recreates `web` alone with a unique non-`latest` `WEB_IMAGE`; guest public smoke verifies availability without using administrator credentials or attachment content.

**Tech Stack:** Docker Compose, SSH, Vue/Vite, Nginx web container, Caddy ingress.

---

### Task 1: Establish a release boundary

**Files:**
- Inspect: `frontend/src/conversation/text_attachment_upload_client.ts`
- Inspect: `frontend/src/conversation/TextMessageAttachmentPicker.vue`
- Inspect: `frontend/src/conversation/TextConversation.vue`
- Inspect: production `api` and `web` image tags

- [x] **Step 1: Re-run the native frontend verification before release**

Run: `npm test -- --run && npm run build` from `frontend`.

Expected: all tests pass and `vue-tsc --noEmit && vite build` exit 0. Do not upload `dist` or `node_modules`.

- [x] **Step 2: Generate and verify an unused pinned local image tag and exact remote stage**

```powershell
$tag = "voice-platform-web:release-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$stage = "/tmp/voice-platform-web-$($tag.Split(':')[1])"
```

Check that `$tag` is not a `latest` tag and `$stage` does not exist on the host. Record only image tags and service health, never values from `.env`.

### Task 2: Build and recreate web only

**Files:**
- Transfer: `frontend/src/conversation/message_client.ts`
- Transfer: `frontend/src/conversation/message_store.ts`
- Transfer: `frontend/src/conversation/text_attachment_upload_client.ts`
- Transfer: `frontend/src/conversation/TextMessageAttachmentPicker.vue`
- Transfer: `frontend/src/conversation/TextConversation.vue`
- Transfer: `frontend/src/conversation/MessageItem.vue`
- Transfer: `frontend/src/conversation/TextMessageAttachments.vue`

- [x] **Step 1: Copy only runtime overlay files to the verified `0700` stage**

```powershell
scp -i $sshKey frontend/src/conversation/text_attachment_upload_client.ts "$target`:$stage/text_attachment_upload_client.ts"
scp -i $sshKey frontend/src/conversation/TextMessageAttachmentPicker.vue "$target`:$stage/TextMessageAttachmentPicker.vue"
```

Copy the other five named files individually. Do not copy test files, plans, `.env`, `dist`, credentials, or an entire directory.

- [x] **Step 2: Overlay, build a unique image, and update only `WEB_IMAGE`**

```sh
sudo install -m 644 "$stage/text_attachment_upload_client.ts" frontend/src/conversation/text_attachment_upload_client.ts
sudo install -m 644 "$stage/TextMessageAttachmentPicker.vue" frontend/src/conversation/TextMessageAttachmentPicker.vue
sudo env WEB_IMAGE="$tag" docker compose build web
sudo sed -i -E "s|^WEB_IMAGE=.*$|WEB_IMAGE=$tag|" .env
```

Install the other five named files to their matching paths. Do not print `.env`, alter `API_IMAGE`, run migrations, or build/recreate `api`, `postgres`, `livekit`, `proxy`, or `fluxer-edge`.

- [x] **Step 3: Recreate just `web` and remove exactly the stage directory**

```sh
sudo env WEB_IMAGE="$tag" docker compose up -d --no-deps --no-build --force-recreate web
sudo docker compose ps web --format '{{.Name}} {{.Image}} {{.Status}}'
sudo rm -rf -- "$stage"
```

Require `web` to be `Up` on the new tag before cleanup. The stage path must equal the previously verified `/tmp/voice-platform-web-...` string.

### Task 3: Guest smoke and deployment record

**Files:**
- Inspect: `https://v.bootybay.ru/`
- Inspect: `https://v.bootybay.ru/api/v1/health`
- Inspect: `https://v.bootybay.ru/api/v1/auth/session`
- Modify: `docs/superpowers/plans/2026-09-18-text-message-attachment-picker-web-release.md`

- [x] **Step 1: Verify public landing, health and unauthenticated session status**

```sh
curl -fsS -o /dev/null -w '%{http_code}\n' https://v.bootybay.ru/
curl -fsS https://v.bootybay.ru/api/v1/health
curl -fsS https://v.bootybay.ru/api/v1/auth/session
```

Expected: landing HTTP 200, health JSON healthy, and session HTTP 200 with `authenticated:false`. Do not log in, upload a real file, create a channel, or send a message.

- [x] **Step 2: Confirm service scope and update execution evidence**

Check that API retains its pre-release tag, web has the unique tag, and the exact stage no longer exists. Change all completed checkboxes to `[x]` and append a concise `## Execution evidence` section with test/build results, the web tag, and guest smoke status.

- [x] **Step 3: Preserve the shared dirty worktree**

Run `git status --short` locally and leave unrelated edits untouched. Do not stage or commit any file from this shared worktree.

## Self-review

- **Spec coverage:** This is a T-044 web delivery step: its only effect is exposing the already-contract-tested private upload flow in the text-channel composer.
- **Security boundary:** Browser requests keep same-origin cookies; upload/download authorization is still server-side. No file payload, storage key, session, password, or `.env` value appears in the release evidence.
- **Intentional gap:** Guest smoke cannot prove authenticated upload or attachment rendering. That validation remains in the owner-operated TODO until safe login input is available.
- **Placeholder scan and types:** All transferred files and commands are exact. `TextAttachmentUpload` flows from picker through the message store to the existing `attachment_ids` contract.

## Execution evidence

- Local release preflight: `npm test -- --run && npm run build` — 48 files, 115 tests passed and production build passed.
- Production release: transferred seven runtime UI files to a `0700` stage; built and recreated only `web` as `voice-platform-web:release-20260918-215931`.
- Scope check: API retained `voice-platform-api:release-20260918-214058`; no migration, API, PostgreSQL, LiveKit, Caddy, persistent volume, or `fluxer-edge` action occurred.
- Guest smoke: `https://v.bootybay.ru/` returned 200; `/api/v1/health` returned `{"status":"ok"}`; `/api/v1/auth/session` returned `{"authenticated":false}`. The exact stage directory was removed.
- Public delivery check: the live `index-BzBy1DCU.js` bundle contains the picker’s “До 10 файлов” UI text.
