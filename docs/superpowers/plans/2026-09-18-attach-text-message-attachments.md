# Attach Text Message Attachments Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Atomically associate up to ten staged attachments with a newly created non-empty text message only when all remain owned by its author, target its channel, and are `UNATTACHED`.

**Architecture:** Extend the existing text-message input and JSON request with optional UUID `attachment_ids`. The PostgreSQL statement first returns an existing idempotent message, otherwise locks and validates every requested attachment, inserts the message and link rows, then transitions those objects to `ATTACHED` in the same statement. The message body remains required, so the existing database body invariant is preserved; attachment-only messages are out of this packet.

**Tech Stack:** Go 1.26, pgx PostgreSQL CTEs, existing Go HTTP handler, OpenAPI 3.1 JSON contract.

---

### Task 1: Validate attachment IDs at the command boundary

**Files:**
- Create: `backend/internal/chat/create_text_message/attachments.go`
- Create: `backend/internal/chat/create_text_message/attachments_test.go`
- Modify: `backend/internal/chat/create_text_message/service.go`

- [x] **Step 1: Write failing unit tests.** Assert one valid attachment ID reaches the store; assert eleven IDs, a malformed ID, and a duplicate ID return `ErrInvalidInput` without persistence.
- [x] **Step 2: Run `go test ./internal/chat/create_text_message`.** Observed the expected compilation failure before `Input.AttachmentIDs` was added.
- [x] **Step 3: Add `AttachmentIDs []string` and validation.** Permit zero through ten UUIDs with no duplicate value, preserving the non-empty text-body requirement.
- [x] **Step 4: Run the focused service test.** PASS: `go test ./internal/chat/create_text_message`.

### Task 2: Atomic CTE persistence

**Files:**
- Modify: `backend/internal/chat/create_text_message/postgres/repository.go`
- Modify: `backend/internal/chat/create_text_message/postgres/repository_test.go`

- [x] **Step 1: Extend the repository test first.** Pass one attachment ID as the seventh query parameter and require statement fragments for an existing idempotent message, `attachment.owner_id = $3`, `attachment.channel_id = channel.id`, `attachment.state = 'UNATTACHED'`, `INSERT INTO message_attachments`, and `SET state = 'ATTACHED'`.
- [x] **Step 2: Run `go test ./internal/chat/create_text_message/postgres`.** Observed the old statement's missing seventh argument before implementation.
- [x] **Step 3: Replace the insert statement.** Return an already-existing idempotency row without modifying links; otherwise lock every requested attachment, reject partial/unavailable sets by returning no row, create ordered link rows, and transition exactly those links to `ATTACHED` within the one statement. A private-server `PREPARE` syntax proof passed in a rolled-back transaction.
- [x] **Step 4: Run focused storage tests.** PASS: `go test ./internal/chat/create_text_message/...`.

### Task 3: HTTP contract and validation

**Files:**
- Modify: `backend/internal/chat/create_text_message/api/http_handler.go`
- Modify: `backend/internal/chat/create_text_message/api/http_handler_test.go`
- Modify: `contracts/openapi.yaml`
- Modify: `docs/ARCHITECTURE_AND_DATA.md`

- [x] **Step 1: Write a handler test carrying `attachment_ids`.** Assert it is passed unchanged from JSON to the creator while actor and channel still come only from session/path.
- [x] **Step 2: Add optional `attachment_ids` to the handler DTO and OpenAPI request schema.** Declare an array of UUIDs with `maxItems: 10` and `uniqueItems: true`; it must not be a response URL or public storage path.
- [x] **Step 3: Document the atomic state transition.** State that an unowned, wrong-channel, attached, or missing ID rejects the entire new-message path without a partial link.
- [x] **Step 4: Run `go test ./...`, `go vet ./...`, and `scripts/verify-contracts.ps1`, then inspect file sizes/status.** PASS on 2026-09-18; no files were staged or committed.
