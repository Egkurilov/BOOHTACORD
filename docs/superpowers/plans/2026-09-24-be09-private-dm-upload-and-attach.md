# BE-09 Private DM Upload and Attach Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A DM participant can stage a private file and attach up to ten owned files to one idempotently sent message without leaking access across pairs.

**Architecture:** Reuse the existing reserved, guarded streaming writer and private file mover. Add DM-specific authorization/finalization leaves. Link attachments in the same PostgreSQL statement as DM message insertion, with row locks and all-candidates validation. The attachment table already has `direct_message_id`; a new link table records ordered message attachments.

**Tech Stack:** Go 1.26, net/http, pgx/PostgreSQL, embedded SQL migrations.

---

### Task 1: DM link migration

**Files:** Create `backend/internal/database/migrate/migrations/0032_create_direct_message_attachments.sql`; modify `backend/internal/database/migrate/run_test.go`.

- [ ] **Step 1: Assert migration order and constraints.** Add expected fragment `CREATE TABLE IF NOT EXISTS direct_message_attachments` before 0033, plus `attachment_id UUID NOT NULL UNIQUE`, `position BETWEEN 0 AND 9`.
- [ ] **Step 2: Run `go test ./internal/database/migrate` from `backend`; expect failure.**
- [ ] **Step 3: Add the migration.** Use `message_id UUID NOT NULL REFERENCES direct_message_messages(id)`, `attachment_id UUID NOT NULL UNIQUE REFERENCES attachments(id)`, `position SMALLINT NOT NULL CHECK (position BETWEEN 0 AND 9)`, PK `(message_id, attachment_id)` and unique `(message_id, position)`.
- [ ] **Step 4: Run the migration test; expect PASS.**

### Task 2: DM upload authorization and private finalization

**Files:** Create `backend/internal/storage/authorize_direct_message_attachment/{service.go,postgres/repository.go,postgres/pool_database.go}`; create `backend/internal/storage/finalize_staged_direct_message_attachment/{service.go,postgres/repository.go,postgres/pool_database.go}`; focused sibling tests.

- [ ] **Step 1: Write failing service and repository tests.** Authorize only when `$actor::uuid IN (participant_one_id, participant_two_id)` and both joined users have `blocked_at IS NULL`; no role predicate. Test invalid UUID and missing pair.
- [ ] **Step 2: Run focused packages; expect failure.**
- [ ] **Step 3: Implement preflight authorization and finalization recheck.** The finalizer generates opaque UUIDs, moves staged file, inserts `attachments` as `UNATTACHED` with `direct_message_id`, and removes moved file on failed DB insert. The recheck closes upload-vs-ban/ACL races.
- [ ] **Step 4: Run focused packages; expect PASS.**

### Task 3: HTTP upload with reserved streaming

**Files:** Create `backend/internal/storage/upload_direct_message_attachment/{service.go,api/http_handler.go}` and focused tests; modify `backend/cmd/api/storage_routes.go`.

- [ ] **Step 1: Write failing HTTP tests.** Multipart `file`, principal/path forwarding, oversized `413 ATTACHMENT_TOO_LARGE`, reserve failure `507 INSUFFICIENT_STORAGE`, unavailable pair `404 NOT_FOUND`, and no storage key in JSON.
- [ ] **Step 2: Run focused tests; expect failure.**
- [ ] **Step 3: Compose `authorize -> stage_upload -> finalize`.** Reuse the existing `stage.New(manager, writer)` so reservation spans the guarded write. Register `POST /api/v1/direct-messages/{directMessageID}/attachments` behind session and upload rate limiter.
- [ ] **Step 4: Run focused tests; expect PASS.**

### Task 4: Atomic send and idempotent attachment links

**Files:** Modify `backend/internal/chat/send_direct_message/{service.go,api/http_handler.go,postgres/repository.go}`; create `attachments.go`; focused tests; modify `backend/cmd/api/chat_routes.go` only if wiring changes.

- [ ] **Step 1: Add failing validation tests.** Reject more than ten, duplicate or malformed attachment UUIDs before store call; verify API `attachment_ids` forwarding.
- [ ] **Step 2: Run focused send tests; expect failure.**
- [ ] **Step 3: Extend input and guarded SQL.** `unnest($7::uuid[]) WITH ORDINALITY` gives ordered candidates; lock matching `UNATTACHED` rows with owner and exact DM predicates; insert only if candidate counts agree. Link only newly inserted message and change only linked attachments to `ATTACHED`. For idempotent replay, return the committed message without changing its links. Preserve `ErrDirectMessageUnavailable` masking.
- [ ] **Step 4: Add migration-backed PostgreSQL cases.** Assert owner/pair/ban rejection, no partial link, replay one ID and one link set, and concurrent attempts to attach the same file to different sends.
- [ ] **Step 5: Run focused packages; expect PASS.**

### Task 5: Metadata-only DM history

**Files:** Modify `backend/internal/chat/list_direct_message_history/{service.go,postgres/repository.go,api/http_handler.go}` and focused tests.

- [ ] **Step 1: Assert each history item has `attachments: []`, including deleted messages, and no `storage_key`.** Run `go test ./internal/chat/list_direct_message_history/...`; expect the new tests to fail.
- [ ] **Step 2: Add a correlated ordered JSON aggregate across `direct_message_attachments` and `attachments` for `ATTACHED` rows only when the message is live.** Expose only `id`, `original_name`, `byte_size` in the service and HTTP response.
- [ ] **Step 3: Run focused tests and a PostgreSQL integration case for live then deleted history; expect PASS.**

### Task 6: Native verification

**Files:** No new runtime files.

- [ ] **Step 1: Run `go test ./internal/chat/send_direct_message/... ./internal/storage/authorize_direct_message_attachment/... ./internal/storage/finalize_staged_direct_message_attachment/... ./internal/storage/upload_direct_message_attachment/... ./internal/database/migrate/...` from `backend`; expect PASS.**
- [ ] **Step 2: Run migration-backed tests against an isolated PostgreSQL schema; expect PASS.**
- [ ] **Step 3: Run `go vet` over the same packages; expect PASS.**
- [ ] **Step 4: Inspect `git status --short`, file sizes, and product diff. Leave staging/commit to root.**

Spec check: owner/pair/ban gates are before and after stream; a 25,000,000-byte guarded writer with reservation is reused; ordered links have a hard cap of ten; unrelated pair and repeat links are blocked by SQL and unique constraints; no storage key appears in responses. No placeholder steps remain.
