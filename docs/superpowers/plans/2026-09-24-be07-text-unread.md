# BE-07 TEXT Read Cursor and Unread Counters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Persist a monotonic read cursor per caller and active TEXT channel, and return caller-local unread counts in channel topology.

**Architecture:** A new cursor leaf validates the authenticated caller, channel and message in one SQL statement, taking a channel row lock that serializes with archive. A per-caller topology query counts undeleted messages after the effective cursor, excluding the caller's own messages. The route remains a thin authenticated binding.

**Tech Stack:** Go 1.26, pgx, PostgreSQL migrations, net/http.

---

### Task 1: Cursor persistence and service

**Files:**
- Create: `backend/internal/database/migrate/migrations/0033_create_channel_read_cursors.sql`
- Create: `backend/internal/chat/advance_text_channel_read_cursor/service.go`
- Create: `backend/internal/chat/advance_text_channel_read_cursor/service_test.go`
- Create: `backend/internal/chat/advance_text_channel_read_cursor/postgres/repository.go`
- Create: `backend/internal/chat/advance_text_channel_read_cursor/postgres/repository_test.go`
- Create: `backend/internal/chat/advance_text_channel_read_cursor/postgres/pool_database.go`

- [x] Write service and repository tests first: invalid UUID, wrong channel/VOICE/archived/deleted message unavailable, backward acknowledgment returns current effective cursor, tuple compare for concurrent advances, and unrelated DB error preserved.
- [x] Run `go test ./internal/chat/advance_text_channel_read_cursor/...` from `backend`; expect a missing implementation failure.
- [x] Create migration with `(account_id, channel_id)` primary key, message ID, timestamp and updated timestamp. Query `channels` for active TEXT and `messages` for same channel; use `FOR SHARE OF channel` and atomic `ON CONFLICT` CASE tuple comparison.
- [x] Run the same Go test; expect PASS.

### Task 2: Authenticated HTTP binding

**Files:**
- Create: `backend/internal/chat/advance_text_channel_read_cursor/api/http_handler.go`
- Create: `backend/internal/chat/advance_text_channel_read_cursor/api/http_handler_test.go`
- Modify: `backend/cmd/api/channel_routes.go`

- [x] Test principal-derived account ID, `PUT /api/v1/channels/{channelID}/read-cursor`, unknown fields, malformed input, and unavailable channel/message mapping to 404.
- [x] Run `go test ./internal/chat/advance_text_channel_read_cursor/api`; expect FAIL before the handler exists.
- [x] Bind service through authenticated middleware and return `{channel_id,message_id,message_created_at}`.
- [x] Run the API test and `go test ./cmd/api`; expect PASS.

### Task 3: Caller-local topology counts

**Files:**
- Modify: `backend/internal/channel/list_topology/service.go`
- Modify: `backend/internal/channel/list_topology/service_test.go`
- Modify: `backend/internal/channel/list_topology/postgres/repository.go`
- Modify: `backend/internal/channel/list_topology/postgres/repository_test.go`
- Modify: `backend/internal/channel/list_topology/api/http_handler.go`
- Modify: `backend/internal/channel/list_topology/api/http_handler_test.go`
- Modify: `backend/internal/database/migrate/run_test.go`

- [x] Test caller ID propagation, TEXT-only `unread_count`, no VOICE count, and SQL filtering by actor, channel, cursor, deleted state and author.
- [x] Run `go test ./internal/channel/list_topology/... ./internal/database/migrate`; expect FAIL before implementation.
- [x] Accept authenticated actor in topology service and query, use a caller-scoped lateral count for active TEXT channels, and serialize `unread_count` only on TEXT rows.
- [x] Run targeted tests plus `go test ./cmd/api`; expect PASS.

### Task 4: Review and validation

**Files:**
- Review: all BE-07 files above.

- [x] Inspect `git diff --check` and changed file sizes against the repository's 120-line hard limit.
- [x] Run `go test ./internal/chat/advance_text_channel_read_cursor/... ./internal/channel/list_topology/... ./internal/database/migrate ./cmd/api` from `backend`.
- [x] Report the contract shape to the root agent for shared OpenAPI, mobile contract, and API documentation updates; do not modify those shared files here.

PostgreSQL 16 integration tests run through WSL against an isolated schema with embedded migrations. They passed for concurrent advances, backward acknowledgements, archived/foreign/VOICE/deleted messages, own-message exclusion, and caller-local unread counters.
