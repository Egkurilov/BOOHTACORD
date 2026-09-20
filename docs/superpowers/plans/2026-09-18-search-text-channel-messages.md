# Text Channel Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add authenticated, cursor-paginated full-text search for non-deleted messages in one current text channel, without exposing deleted content or creating a channel-ACL bypass.

**Architecture:** A new `search_text_messages` leaf follows the proven DM-search shape, but its availability guard is exactly the existing current `TEXT` channel predicate; V1 has no closed-channel ACL. PostgreSQL owns full-text matching through a generated `simple` vector and a partial GIN index. The API route is session-protected and returns a minimal search-result shape; direct-message search and frontend search UI remain separate leaves.

**Tech Stack:** Go 1.26, pgx v5/PostgreSQL, net/http, OpenAPI, Go unit tests.

---

### Task 1: Make the persistence contract explicit and pin its migration

**Files:**
- Create: `backend/internal/database/migrate/migrations/0026_add_text_message_search_index.sql`
- Modify: `backend/internal/database/migrate/run_test.go`

- [x] **Step 1: Extend the migration-runner expectation before adding the migration.**

Append this expected migration fragment to `expected` after migration `0025`:

```go
{"ADD COLUMN IF NOT EXISTS search_vector", "messages_search_idx", "WHERE deleted_at IS NULL"},
```

Run: `Push-Location backend; go test ./internal/database/migrate -count=1; Pop-Location`

Expected: FAIL because there are only 25 embedded migrations.

- [x] **Step 2: Add the idempotent PostgreSQL search index migration.**

```sql
ALTER TABLE messages
    ADD COLUMN IF NOT EXISTS search_vector tsvector
    GENERATED ALWAYS AS (to_tsvector('simple', body)) STORED;

CREATE INDEX IF NOT EXISTS messages_search_idx
    ON messages USING GIN (search_vector)
    WHERE deleted_at IS NULL;
```

Run the same command. Expected: PASS and the migration remains safe when replayed by the runner.

### Task 2: Add the bounded domain search leaf with tests first

**Files:**
- Create: `backend/internal/chat/search_text_messages/service.go`
- Create: `backend/internal/chat/search_text_messages/service_test.go`

- [x] **Step 1: Write the service tests.**

Define fixed UUID channel constants. Assert a three-result store response is truncated to a requested limit of two, returns the second ID as `NextCursor`, and sends a trimmed query to storage. Table-test invalid channel UUID, blank query, 257-rune query, malformed cursor, and limits outside `1..100`; storage must not be called.

- [x] **Step 2: Run the focused domain test before implementation.**

Run: `Push-Location backend; go test ./internal/chat/search_text_messages -count=1; Pop-Location`

Expected: FAIL because the package does not exist.

- [x] **Step 3: Implement the leaf.**

```go
type Input struct { ChannelID, Query, Before string; Limit int }
type Request struct{ Input }
type Message struct { ID, ChannelID, AuthorID, Body string; CreatedAt time.Time; EditedAt *time.Time; Revision int }
type Result struct { Messages []Message; NextCursor string }
type Store interface { Search(context.Context, Request) ([]Message, error) }
```

`Search` trims whitespace, validates UUID/cursor/query-rune-count/limit before persistence, maps `ErrChannelUnavailable`, passes the requested limit to storage, and removes a repository-supplied lookahead before returning a cursor. The repository asks PostgreSQL for `Limit+1` rows. The leaf must never receive an actor role or use a client-supplied access decision.

- [x] **Step 4: Re-run the focused domain test.**

Expected: PASS.

### Task 3: Enforce current text-channel scope in the PostgreSQL adapter

**Files:**
- Create: `backend/internal/chat/search_text_messages/postgres/repository.go`
- Create: `backend/internal/chat/search_text_messages/postgres/repository_test.go`
- Create: `backend/internal/chat/search_text_messages/postgres/pool_database.go`

- [x] **Step 1: Write repository tests for availability and query constraints.**

Use fakes equivalent to `search_direct_message_history/postgres`. Assert unavailable current-text-channel check maps to `ErrChannelUnavailable`. For a successful search, assert the statement contains all of:

```text
kind = 'TEXT'
archived_at IS NULL
m.deleted_at IS NULL
m.search_vector @@ websearch_to_tsquery('simple', $3)
ORDER BY m.created_at DESC, m.id DESC
```

Also assert parameters are `(channel ID, optional cursor, query, limit+1)` and that the row mapper contains no deleted-message field/body fallback.

- [x] **Step 2: Implement the repository and pool adapter.**

Use a `SELECT EXISTS` guard against `channels` with `kind = 'TEXT' AND archived_at IS NULL`. Search only `messages` whose `channel_id` is that guarded ID, whose `deleted_at IS NULL`, and whose generated vector matches `websearch_to_tsquery('simple', $3)`. Resolve `before` inside the same channel and apply `(created_at, id)` descending cursor comparison. Return only ID/channel/author/body/timestamps/revision and wrap database failures with bounded operation context.

- [x] **Step 3: Run persistence and domain tests.**

Run: `Push-Location backend; go test ./internal/chat/search_text_messages/... -count=1; Pop-Location`

Expected: PASS.

### Task 4: Bind the authenticated endpoint and document the contract

**Files:**
- Create: `backend/internal/chat/search_text_messages/api/http_handler.go`
- Create: `backend/internal/chat/search_text_messages/api/http_handler_test.go`
- Modify: `backend/cmd/api/chat_routes.go`
- Modify: `contracts/openapi.yaml`
- Modify: `docs/API_AND_REALTIME.md`
- Modify: `scripts/verify-contracts.ps1`

- [x] **Step 1: Write handler tests.**

Assert `GET /api/v1/channels/{channelID}/search?query=%22точная+фраза%22&before=<uuid>&limit=10` reaches the searcher with its path/query values and serializes a 200 page. Assert blank query and non-integer page yield bounded `400 VALIDATION_FAILED`; unavailable channel yields `404 NOT_FOUND`.

- [x] **Step 2: Implement the handler and route binding.**

Parse `limit` as an optional integer defaulting to 50. Map domain validation to Russian `400`, missing/non-text/archived channel to `404`, and unexpected failures to `500`, all with request ID. Bind exactly:

```go
mux.Handle("GET /api/v1/channels/{channelID}/search", sessionapi.Require(sessions)(textMessageSearchAPI.NewHandler(textMessageSearch)))
```

The session middleware is the server-side access boundary; no role is accepted or sent to the service.

- [x] **Step 3: Add the OpenAPI and operator contract text.**

Document query/before/limit (1–100), newest-first cursor page, `simple` PostgreSQL full-text semantics, exclusion of deleted content, and that only current text channels are searchable. Define `TextMessageSearchPage` and `TextMessageSearchResult` with `id`, `channel_id`, `author_id`, `body`, `created_at`, optional `edited_at`, and `revision`; do not include deleted, attachments, or message client id.

- [x] **Step 4: Run handler and contract checks.**

Run:

```powershell
Push-Location backend
go test ./internal/chat/search_text_messages/... -count=1
Pop-Location
scripts/verify-contracts.ps1
scripts/verify-spec-traceability.ps1
```

Expected: all commands pass.

### Task 5: Verify the leaf without inventing integration evidence

**Files:**
- Modify: `docs/superpowers/plans/2026-09-18-search-text-channel-messages.md`

- [x] **Step 1: Run the full Go suite, formatting, build and scoped review.**

Run:

```powershell
Push-Location backend
gofmt -w internal/chat/search_text_messages cmd/api/chat_routes.go
go test ./... -count=1
go vet ./...
go build ./cmd/api
Pop-Location
git diff --check
git status --short
```

Expected: code checks pass; inspect file sizes before any staging. Do not create a POC/release evidence record: this is unit/contract work, not a real PostgreSQL, browser, LiveKit, capacity, or hardware result.

**Coverage review:** This leaf advances T-043 with current-text-channel search only. It deliberately does not implement direct-message search UI, global search, cross-channel search, deleted-content search, attachment content search, message-event replay, or a real PostgreSQL integration test; those remain distinct work and may not be claimed as complete.
