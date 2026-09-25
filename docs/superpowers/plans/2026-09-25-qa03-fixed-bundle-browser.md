# QA-03 Fixed-Bundle Browser Verification Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Verify private DM realtime and browser notification behavior using one fixed Vue bundle, real Go/PostgreSQL services and separate synthetic browser sessions.

**Architecture:** Build the current client and API, migrate an isolated PostgreSQL schema, and serve the built bundle through a localhost reverse proxy that forwards HTTP and WebSocket to Go. Register two synthetic members through the public API, issue separate sessions, and remove all temporary state after acceptance.

**Tech Stack:** Vue 3/Vite, Go `net/http/httputil`, PostgreSQL 16, Chrome and Codex in-app browser.

---

### Task 1: Pin the candidate

**Files:** Read `frontend/package.json`, `frontend/dist/assets/*`, `backend/cmd/api/main.go`; do not commit generated bundles.

- [x] Run `npm run build` in `frontend` and build `./cmd/api`, `./cmd/migrate` and `./cmd/bootstrap_admin` into exact `/var/tmp/boohtacord-qa03-*` binaries in `backend`.
- [x] Record `git rev-parse HEAD` and SHA-256 of the built JS/CSS entry files before opening a browser. Stop if either build fails.

### Task 2: Create the isolated fixture

**Files:** Temporary `/var/tmp/boohtacord_qa03_fixture.py` and `/var/tmp/boohtacord_qa03_proxy.go`; neither belongs in Git.

- [x] Create `qa03_browser_<random>` in the local `voice_platform_test` database; set that schema as the API search path. Run the project migrator, bootstrap a synthetic administrator, start the Go API on `127.0.0.1:18083`, then register three synthetic `MEMBER` accounts.
- [x] Log in the accounts through `POST /api/v1/auth/login`, retain secure cookies only in a mode-0600 temporary file, and start a localhost proxy on `127.0.0.1:18769`. `GET /__qa/sender` and `/__qa/recipient` set only their corresponding synthetic cookie and redirect to `/`; `/api/` forwards HTTP and WebSocket; all other paths serve `frontend/dist` with SPA fallback.
- [x] Check `/api/v1/health` through the proxy and inspect the browser's authenticated session before interaction. Do not print passwords, cookies or message bodies in logs or evidence.

### Task 3: Verify delivery and privacy

**Files:** Browser state only; no production files.

- [x] Open the sender in the in-app browser and recipient in Chrome; confirm separate authenticated accounts and online WebSocket presence. Create a DM, send a synthetic message from one participant and assert the other participant's unread badge and title change without reload.
- [ ] Keep the recipient tab hidden in Chrome, enable notifications only after browser-policy confirmation at action time, and assert exactly one generic notification for a new unread DM. Confirm its title/body contain no sender name, DM body or attachment name. Edit/delete must refresh the history without creating a new notification; own/read events must not notify.
- [x] Use a third synthetic session for HTTP 404 on foreign DM history/search.
- [ ] Confirm the third browser receives no private hint and duplicate event delivery does not duplicate a browser notification.

### Task 4: Record and clean up

**Files:** Create `evidence/qa/qa03-fixed-bundle-browser-2026-09-25-001.json`; update `backlog/VERIFICATION_TODO.md`, `TODO.md`, and `DONE.md` only when their status criteria are met.

- [x] Stop the proxy and API; drop the exact isolated schema and delete exact temporary cookie/script/binary paths. Verify ports `18083` and `18769` have no listener and no `qa03_browser_%` schema remains. The in-app-browser sender tab could not be closed after its native confirm blocked CDP; it is ephemeral and must not be marked for handoff.
- [x] Write observed results with candidate commit/bundle hashes, exact PASS/PARTIAL/NOT_RUN status and limitations. Run `scripts/verify-spec-traceability.ps1`, inspect Git status and changed file sizes, then stage only the evidence and documentation files.
