# BE-14 Realtime Replay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resume metadata-only realtime hints from a bounded PostgreSQL journal without exposing events after an ACL or session change.

**Architecture:** The in-process Hub writes replayable hint metadata to a PostgreSQL journal before live delivery. The WebSocket route subscribes before reading a bounded suffix after an acknowledged `event_id`, rechecks the current session and resource ACL for every replayed hint, and deduplicates queued live copies. A process boot epoch prevents replay across an unclosed domain-commit/publication gap on restart; invalid or expired cursors and journal failures demand REST resync.

**Tech Stack:** Go 1.26, pgx/PostgreSQL, coder/websocket, migration 0036, native `go test`.

---

### Task 1: Define safe journal records and cursor policy

**Files:**
- Create: `backend/internal/database/migrate/migrations/0036_create_realtime_events.sql`
- Create: `backend/internal/realtime/replay_event/postgres/repository.go`
- Create: `backend/internal/realtime/replay_event/postgres/repository_test.go`

- [ ] Write tests proving only typed channel/message/DM/voice metadata can be persisted, recipient UUIDs are retained for private hints, an unknown/expired/foreign-epoch cursor returns resync, and more than 512 eligible rows returns resync.
- [ ] Run `go test ./internal/realtime/replay_event/postgres` from `backend`; expect the new tests to fail.
- [ ] Implement a seven-day journal with monotonically increasing sequence, UUID event ID, boot epoch, kind, JSONB payload and optional recipient UUID array. Retain no body, token or attachment key. Bound physical expiry deletion per insert.
- [ ] Rerun the focused tests; expect pass. Run migration test with `TEST_DATABASE_URL` in a disposable schema when available.

### Task 2: Preserve live continuity in the event hub

**Files:**
- Modify: `backend/internal/realtime/event_hub/hub.go`
- Modify: `backend/internal/realtime/event_hub/delivery.go`
- Modify: `backend/internal/realtime/event_hub/targeted.go`
- Create: `backend/internal/realtime/event_hub/durable_test.go`

- [ ] Write tests for append-before-broadcast, targeted private recipient persistence, duplicate event ID idempotency, and storage failure causing every subscriber to resync rather than silently continuing.
- [ ] Run `go test ./internal/realtime/event_hub`; expect failures.
- [ ] Add an attachable journal interface and a process boot epoch; use it only for replayable metadata hints. Treat append failure as continuity failure for that boot epoch.
- [ ] Rerun focused tests; expect pass.

### Task 3: Replay with current authority

**Files:**
- Modify: `backend/internal/realtime/connect_session/http_handler.go`
- Modify: `backend/internal/realtime/connect_session/event_stream.go`
- Create: `backend/internal/realtime/connect_session/replay.go`
- Create: `backend/internal/realtime/connect_session/replay_test.go`

- [ ] Write WebSocket tests for restart, unknown/expired cursor, duplicate queued event, overflow, revoked session, and revoked DM/channel/lease access. Assert third-party DM IDs never reach an unauthorized socket.
- [ ] Run `go test ./internal/realtime/connect_session`; expect failures.
- [ ] On `after`, query a bounded suffix. Before each replay write, reauthenticate the original cookie and ask the journal to authorize the resource against current PostgreSQL state. If any check fails or the journal cannot guarantee continuity, send `connection.resync_required`; never claim replay success.
- [ ] Rerun focused tests; expect pass.

### Task 4: Wire application and verify

**Files:**
- Modify: `backend/cmd/api/main.go`
- Modify: `backend/cmd/api/realtime_routes.go`
- Modify: `backend/internal/database/migrate/run_test.go` only when the adjacent migration expectation is stable

- [ ] Wire the shared PostgreSQL journal to Hub and WebSocket ingress, preserving the BE-04 notification worker setup.
- [ ] Run `go test ./internal/realtime/... ./cmd/api ./internal/database/migrate`, `go vet ./internal/realtime/... ./cmd/api`, and any local PostgreSQL integration test; report skipped hardware or DB checks honestly.
- [ ] Inspect changed file sizes and `git status --short` before handoff. Do not stage or commit: the parent agent owns shared integration.

**Contract for coordinator:** `after` is the last *applied replayable* event UUID, acknowledged by the next WebSocket URL. Events have seven-day logical retention. A cursor outside that window, from a different process epoch, unknown to the journal, or yielding over 512 rows causes `connection.resync_required` and REST refresh. `connection.ready` and presence events are ephemeral and must not become `after` cursors. The journaling source is currently after the domain transaction for several producers, so cross-restart replay is intentionally forbidden until every producer has a transactional outbox.

**Execution record:** BE-14 focused tests, `go vet`, WSL PostgreSQL migration/ACL and concurrent sequence-order integration, and WSL `go test -race` passed on 25 September 2026. Full `go test ./...` was attempted and failed in concurrently edited chat/mention tests outside BE-14 (`create_text_message` and `send_direct_message` Result comparisons and repository expectations); the coordinator owns that integration. No files were staged or committed by this worker.
