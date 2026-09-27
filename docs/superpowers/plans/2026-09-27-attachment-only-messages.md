# Attachment-only TEXT and DM messages Implementation Plan

> **For agentic workers:** Use the project AGENTS.md and Slavik Gym leaf rules. Steps use checkbox syntax; TEXT and DM have separate owners and one integration owner for shared migration/contracts.

**Goal:** Allow a message containing at least one valid attachment and no text in TEXT or DM, while rejecting a request containing neither text nor attachments.

**Architecture:** Keep existing atomic attachment claims, ACL and idempotency paths. Relax only the live-message body database constraint and create-service validation; enforce non-empty content in each service and insert query. Existing read/search/delete projections retain `body: ""` for attachment-only live messages.

**Tech Stack:** Go 1.26, PostgreSQL migrations, OpenAPI, Go integration tests.

---

### Task 1: Shared migration and contract (integration owner)

**Files:** `backend/internal/database/migrate/migrations/0039_allow_attachment_only_messages.sql`, `contracts/openapi.yaml`.

- [ ] Add one forward migration that drops `messages_body_or_deleted_marker` and `direct_message_messages_body_or_deleted_marker`, then restores each with `deleted_at IS NULL AND char_length(body) BETWEEN 0 AND 8000` or `deleted_at IS NOT NULL AND body = ''`.
- [ ] In `TextMessageCreateRequest` and `DirectMessageMessageCreateRequest`, set `body.minLength` to `0`; keep `body` required and `maxLength: 8000`. Describe the conditional invariant: an empty body requires at least one attachment ID. Leave edit-request schemas at `minLength: 1`.
- [ ] Run `pwsh -NoProfile -File scripts/verify-contracts.ps1` and `pwsh -NoProfile -File scripts/verify-spec-traceability.ps1`; both must exit 0.

### Task 2: BE-19 TEXT create (TEXT agent)

**Files:** `backend/internal/chat/create_text_message/service.go`, `service_test.go`, `postgres/repository.go`, focused PostgreSQL integration tests in that leaf.

- [ ] Add red service tests for `Body: "", AttachmentIDs: []string{validID}` succeeding and `Body: "", AttachmentIDs: nil` returning `ErrInvalidInput`.
- [ ] Replace the unconditional empty-body rejection with `input.Body == "" && len(input.AttachmentIDs) == 0`; retain UTF-8, NUL, length and ID validation.
- [ ] Guard the insert with `AND ($5 <> '' OR cardinality($7::uuid[]) > 0)` while preserving channel, reply, mention, attachment claim and idempotent retry predicates.
- [ ] Add PostgreSQL tests proving one attachment-only row/link, rejection of foreign or already-attached objects and one row/link for concurrent same-key retry. Preserve soft-delete behavior.
- [ ] Run focused `go test -count=1` for the TEXT service and PostgreSQL leaf; report PostgreSQL tests as NOT_RUN if no database is available.

### Task 3: BE-20 DM create (DM agent)

**Files:** `backend/internal/chat/send_direct_message/service.go`, `service_test.go`, `postgres/repository.go`, focused PostgreSQL integration tests in that leaf.

- [ ] Add red service tests for valid attachment-only DM and empty request rejection.
- [ ] Replace the unconditional empty-body rejection with `input.Body == "" && len(input.AttachmentIDs) == 0`; retain current validation.
- [ ] Guard the DM insert with `AND ($5 <> '' OR cardinality($7::uuid[]) > 0)` without changing active-pair ACL, private hints, attachment locking or idempotency.
- [ ] Add PostgreSQL tests for participant-only attachment-only history, admin/foreign attachment rejection and concurrent same-key retry producing one row/link.
- [ ] Run focused `go test -count=1` for the DM service and PostgreSQL leaf; report PostgreSQL tests as NOT_RUN if no database is available.

### Task 4: Integration and release (integration owner)

- [ ] Review both diffs and run relevant Go unit/integration tests with PostgreSQL, full `go test ./...`, `go vet ./...`, contract/traceability checks and `git diff --check`.
- [ ] Update `backlog/BACKEND_TODO.md`, `TODO.md` and `DONE_RECENT.md` only after source checks pass; keep FE-54/55 and browser QA-05 open.
- [ ] Inspect `git status --short` and changed file sizes; stage exact files, commit and push GitVerse `master`.
- [ ] Wait for trusted GitVerse CI/deploy and verify production health. Record any unrun physical/browser acceptance as open.
