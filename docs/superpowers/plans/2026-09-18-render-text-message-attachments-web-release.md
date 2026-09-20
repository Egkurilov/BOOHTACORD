# Render Text Message Attachments Web Release Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish the validated text-message attachment metadata/download UI in one unique non-`latest` web image, leaving API, PostgreSQL, LiveKit, Caddy and persistent storage untouched.

**Architecture:** The already-deployed API history contract and protected download endpoint are prerequisites. The production web source receives only the exact frontend files for this leaf, then Compose builds and recreates `web` alone. Guest landing/session smoke verifies availability; no user logs in, uploads, reads message history, or transfers a file.

**Tech Stack:** Docker Compose, SSH, Vue/Vite web image, Caddy public ingress.

---

### Task 1: Select a safe web release target

**Files:**
- Inspect: production API/web image identities
- Transfer: `frontend/src/conversation/message_client.ts`, `text_message_attachment_url.ts`, `TextMessageAttachments.vue`, `MessageItem.vue`, `frontend/src/style.css`

- [x] **Step 1: Generate an unused web image tag and a private staging directory.**

```powershell
$tag = "voice-platform-web:release-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$stage = "/tmp/voice-platform-web-$($tag.Split(':')[1])"
```

Require the image tag and exact staging directory to be absent before writing; record only API/web tags, never environment values.

- [x] **Step 2: Confirm the release does not require a migration or API restart.**

The required API history metadata and same-origin download endpoint are already deployed. Do not run `migrate`, modify volumes or restart API, PostgreSQL, LiveKit or Caddy.

### Task 2: Build and recreate web only

**Files:**
- Modify remotely: the five exact frontend runtime source files and `.env` `WEB_IMAGE` only

- [x] **Step 1: Transfer only the exact UI overlay into a `0700` stage.**

```powershell
scp frontend/src/conversation/message_client.ts "$target`:$stage/message_client.ts"
scp frontend/src/conversation/TextMessageAttachments.vue "$target`:$stage/TextMessageAttachments.vue"
```

Transfer the remaining named runtime UI files individually. Do not transfer `dist`, `node_modules`, any test file, docs, credentials or unrelated dirty source.

- [x] **Step 2: Overlay sources, build a unique web image and set `WEB_IMAGE`.**

```sh
sudo install -m 644 "$stage/message_client.ts" frontend/src/conversation/message_client.ts
sudo install -m 644 "$stage/TextMessageAttachments.vue" frontend/src/conversation/TextMessageAttachments.vue
sudo env WEB_IMAGE="$image" docker compose build web
sudo sed -i -E "s|^WEB_IMAGE=.*$|WEB_IMAGE=$image|" .env
```

Require build success; never use `latest` or output `.env`.

- [x] **Step 3: Recreate only the web service and remove exactly the verified stage.**

```sh
sudo env WEB_IMAGE="$image" docker compose up -d --no-deps --no-build --force-recreate web
sudo docker compose ps web --format '{{.Name}} {{.Image}} {{.Status}}'
```

Require `Up`, retain the API's existing tag, and remove only the exact `/tmp/voice-platform-web-...` directory after success.

### Task 3: Guest smoke, not attachment evidence

**Files:**
- Inspect: `https://v.bootybay.ru/`, `/health`, `/api/v1/auth/session`

- [x] **Step 1: Confirm landing, health and guest session are HTTP 200.**

The guest session must remain `authenticated:false`; no owner credential is read or entered.

- [x] **Step 2: Recheck API/web tags and staging cleanup.**

API must retain its current tag, web must show the unique new tag, and the exact stage must be absent. This does not prove a participant can see metadata, download a file or upload an attachment.
