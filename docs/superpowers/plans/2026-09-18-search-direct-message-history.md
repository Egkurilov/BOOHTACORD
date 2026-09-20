# Direct Message Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide cursor-paginated Russian/English full-text search of non-deleted messages in one caller-owned DM, preserving the two-participant ACL in the server and PostgreSQL query.

**Architecture:** A bounded `search_direct_message_history` Go leaf validates the caller, DM ID, query, cursor and limit before delegating to PostgreSQL. The repository re-establishes pair membership inside a CTE, excludes deleted messages, calls `websearch_to_tsquery('simple', query)` for words and quoted exact phrases, and obtains its vector from a generated, GIN-indexed column.

**Tech Stack:** Go 1.26, `net/http`, PostgreSQL full-text search, pgx, OpenAPI JSON/YAML contract, existing PowerShell verifiers.

---

### Task 1: Search service contract

**Files:**
- Create: `backend/internal/chat/search_direct_message_history/service.go`
- Create: `backend/internal/chat/search_direct_message_history/service_test.go`

- [x] **Step 1: Write service tests for lookahead pagination and rejected input before persistence.**

```go
result, err := New(store).Search(context.Background(), Input{ActorID: actorID, DirectMessageID: directMessageID, Query: "привет", Limit: 2})
if err != nil || len(result.Messages) != 2 || result.NextCursor != "message-2" { t.Fatal(result, err) }
for _, input := range []Input{{ActorID: "bad", DirectMessageID: directMessageID, Query: "x", Limit: 10}, {ActorID: actorID, DirectMessageID: directMessageID, Query: " ", Limit: 10}, {ActorID: actorID, DirectMessageID: directMessageID, Query: "x", Limit: 101}} {
  if _, err := New(store).Search(context.Background(), input); !errors.Is(err, ErrInvalidInput) || store.called { t.Fatal(input, err) }
}
```

- [x] **Step 2: Run the focused service test to verify the package is absent.**

Run: `go test ./internal/chat/search_direct_message_history`

Expected: FAIL because the package does not exist.

- [x] **Step 3: Implement the input and lookahead service.**

```go
type Input struct { ActorID, DirectMessageID, Query, Before string; Limit int }
type Message struct { ID, DirectMessageID, AuthorID, Body string; CreatedAt time.Time; EditedAt *time.Time; Revision int }
type Result struct { Messages []Message; NextCursor string }
type Store interface { Search(context.Context, Request) ([]Message, error) }
func (service Service) Search(context context.Context, input Input) (Result, error)
```

Reject non-UUID actor, DM or cursor; trim and require a query of 1–256 Unicode code points; accept only limit 1–100; and transform `limit + 1` rows into a returned page and final ID cursor. Map the repository's unavailable sentinel unchanged and wrap unexpected errors without a message body.

- [x] **Step 4: Run the focused service test.**

Run: `go test ./internal/chat/search_direct_message_history`

Expected: PASS.

### Task 2: Database search with participant ACL

**Files:**
- Create: `backend/internal/database/migrate/migrations/0022_add_direct_message_search_index.sql`
- Create: `backend/internal/chat/search_direct_message_history/postgres/repository.go`
- Create: `backend/internal/chat/search_direct_message_history/postgres/pool_database.go`
- Create: `backend/internal/chat/search_direct_message_history/postgres/repository_test.go`

- [x] **Step 1: Write the repository test that asserts the ACL CTE, deleted-message exclusion, cursor ordering, web search query and index-backed column usage.**

```go
for _, fragment := range []string{
  "$2::uuid IN (dm.participant_one_id, dm.participant_two_id)",
  "m.deleted_at IS NULL", "m.search_vector @@ websearch_to_tsquery('simple', $4)",
  "ORDER BY m.created_at DESC, m.id DESC",
} { if !strings.Contains(database.statement, fragment) { t.Fatal(fragment) } }
```

- [x] **Step 2: Run the focused package test and confirm it fails before the repository exists.**

Run: `go test ./internal/chat/search_direct_message_history/postgres`

Expected: FAIL because the package does not exist.

- [x] **Step 3: Add the generated-vector migration and repository.**

```sql
ALTER TABLE direct_message_messages
  ADD COLUMN IF NOT EXISTS search_vector tsvector GENERATED ALWAYS AS (to_tsvector('simple', body)) STORED;
CREATE INDEX IF NOT EXISTS direct_message_messages_search_idx
  ON direct_message_messages USING GIN (search_vector)
  WHERE deleted_at IS NULL;
```

Use a `readable_pair` CTE that contains `direct_messages.id` only when `$2::uuid` belongs to the pair. Select rows only through that CTE, enforce `m.deleted_at IS NULL`, use `websearch_to_tsquery('simple', $4)`, apply the `(created_at, id)` cursor and `LIMIT $5`. Never accept a DM result merely because an administrator requested it. Map no readable pair to `ErrDirectMessageUnavailable` and scan only result metadata/body already authorized for this response.

- [x] **Step 4: Run the focused repository tests.**

Run: `go test ./internal/chat/search_direct_message_history/postgres`

Expected: PASS.

### Task 3: Protected HTTP route and public contract

**Files:**
- Create: `backend/internal/chat/search_direct_message_history/api/http_handler.go`
- Create: `backend/internal/chat/search_direct_message_history/api/http_handler_test.go`
- Modify: `backend/cmd/api/chat_routes.go`
- Modify: `contracts/openapi.yaml`
- Modify: `docs/API_AND_REALTIME.md`
- Modify: `scripts/verify-contracts.ps1`

- [x] **Step 1: Write a handler test for principal-derived actor, `query`, cursor/limit and error mapping.**

```go
request := httptest.NewRequest(http.MethodGet, "/api/v1/direct-messages/"+directMessageID+"/search?query=%22exact+phrase%22&before="+before+"&limit=10", nil)
request = request.WithContext(sessionapi.WithPrincipal(request.Context(), sessionapi.Principal{AccountID: actorID}))
if recorder.Code != http.StatusOK || input.ActorID != actorID || input.Query != `"exact phrase"` || input.Limit != 10 { t.Fatal(recorder.Code, input) }
```

- [x] **Step 2: Run the focused handler test to verify the API package is absent.**

Run: `go test ./internal/chat/search_direct_message_history/api`

Expected: FAIL because the package does not exist.

- [x] **Step 3: Implement the handler, registration and contract.**

```go
mux.Handle("GET /api/v1/direct-messages/{directMessageID}/search", sessionapi.Require(sessions)(searchapi.NewHandler(directMessageSearch)))
```

Read the account exclusively from session middleware. Return `400 VALIDATION_FAILED` for malformed query/page, `404 NOT_FOUND` for a nonparticipant/unavailable pair, and a generic `500 INTERNAL` for storage failure. Add the OpenAPI operation with required `query`, optional `before` and `limit`, plus `DirectMessageSearchPage` and `DirectMessageSearchResult` schemas. Document that only non-deleted messages of the caller's selected pair are searched, the query uses PostgreSQL `simple` configuration for Cyrillic and Latin text, and quoted terms are exact phrases.

- [x] **Step 4: Run focused handler and contract verification.**

Run: `go test ./internal/chat/search_direct_message_history/api`

Run: `powershell -ExecutionPolicy Bypass -File scripts/verify-contracts.ps1`

Expected: both commands PASS.

### Task 4: Integration-level checks and scope review

**Files:**
- Modify: `docs/superpowers/plans/2026-09-18-search-direct-message-history.md`

- [x] **Step 1: Format and test the Go workspace.**

Run: `gofmt -w internal/chat/search_direct_message_history cmd/api/chat_routes.go`

Run: `go test ./...`

Run: `go vet ./...`

Expected: all commands PASS.

- [x] **Step 2: Build the API and run traceability/diff checks.**

Run: `go build -o voice-platform-api-dm-search-check.exe ./cmd/api`

Run: `powershell -ExecutionPolicy Bypass -File scripts/verify-spec-traceability.ps1`

Run: `git diff --check`

Expected: build and verifiers exit `0`; delete only the explicitly named temporary executable after the build check.

- [x] **Step 3: Inspect changed sizes without staging.**

Run: `git status --short`

Run: `Get-ChildItem internal/chat/search_direct_message_history/service.go,internal/chat/search_direct_message_history/api/http_handler.go,internal/chat/search_direct_message_history/postgres/repository.go | Select-Object Name,Length`

Expected: files stay under the 120-line hard ratchet and the shared dirty tree is not staged or committed.

## Self-review

- REQ-SEARCH-01 is narrowed deliberately to the selectable current-DM search leaf; common-channel and all-owned-DM search remain independent follow-on leaves.
- The quoted phrase and Cyrillic/Latin mechanics are owned by PostgreSQL `websearch_to_tsquery('simple', query)` and a GIN-indexed generated vector.
- The same repository query contains pair membership and row selection, so a client-supplied DM ID or administrator role cannot bypass ownership.
- All function/type names, cursor field, endpoint path, SQL parameter order and response schemas are consistent across tasks.
- No deferred work or vague failure-handling instruction remains in this plan.
