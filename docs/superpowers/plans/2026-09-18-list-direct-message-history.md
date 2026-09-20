# Direct-message History Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let either participant of an existing 1:1 direct message page through its history without exposing it to administrators or non-participants.

**Architecture:** Add an isolated Go leaf whose service validates the caller, DM, cursor, and page size before repository access. The PostgreSQL repository checks caller membership in both its availability and paged-read statements; it deliberately does not require either account to be unblocked, so the unblocked participant retains history after a block while new sends remain separately guarded. A composite index supports newest-first cursor pagination, and a session-protected GET route exposes a deleted-content-safe DTO.

**Tech Stack:** Go 1.26, PostgreSQL/pgx, net/http, embedded migrations, OpenAPI 3.1, Go testing.

---

### Task 1: Write the DM-history behavior tests

**Files:**
- Create: `backend/internal/chat/list_direct_message_history/service_test.go`
- Create: `backend/internal/chat/list_direct_message_history/postgres/repository_test.go`
- Create: `backend/internal/chat/list_direct_message_history/api/http_handler_test.go`
- Modify: `backend/internal/database/migrate/run_test.go`

- [x] **Step 1: Write the failing service tests for page bounds, caller validation, and lookahead trimming**

```go
result, err := New(store).List(context.Background(), Input{ActorID: actorID, DirectMessageID: directMessageID, Limit: 2})
if err != nil || len(result.Messages) != 2 || result.NextCursor != "message-2" || store.request.Limit != 2 {
    t.Fatalf("result=%#v request=%#v error=%v", result, store.request, err)
}
_, err = New(&fakeStore{}).List(context.Background(), Input{ActorID: "nope", DirectMessageID: directMessageID, Limit: 10})
if !errors.Is(err, ErrInvalidInput) { t.Fatalf("error=%v", err) }
```

- [x] **Step 2: Write the failing repository tests for active-pair-only SQL and deleted markers**

```go
result, err := New(database).List(context.Background(), Request{Input: Input{ActorID: actorID, DirectMessageID: directMessageID, Limit: 2}})
if err != nil || len(result) != 1 || result[0].Body != "" || !result[0].Deleted { t.Fatalf("result=%#v error=%v", result, err) }
for _, fragment := range []string{"$2::uuid IN (dm.participant_one_id, dm.participant_two_id)", "direct_message_id = (SELECT id FROM readable_pair)", "CASE WHEN m.deleted_at IS NULL THEN m.body ELSE '' END"} {
    if !strings.Contains(database.statement, fragment) { t.Fatalf("missing %q", fragment) }
}
```

- [x] **Step 3: Write the failing route and migration assertions**

```go
request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: actorID, Role: "ADMINISTRATOR"}))
handler.ServeHTTP(recorder, request)
if recorder.Code != http.StatusOK || input.ActorID != actorID || !strings.Contains(recorder.Body.String(), `"deleted":true`) { t.Fatalf("status=%d input=%#v", recorder.Code, input) }
```

```go
if len(executor.statements) != 19 || !strings.Contains(executor.statements[18], "direct_message_messages_history_idx") {
    t.Fatalf("statements=%#v", executor.statements)
}
```

- [x] **Step 4: Run the focused tests and record the expected failure**

Run: `go test ./internal/chat/list_direct_message_history/... ./internal/database/migrate`

Expected: FAIL because the DM-history package and pagination index are absent.

### Task 2: Implement the read ACL and cursor page

**Files:**
- Create: `backend/internal/chat/list_direct_message_history/service.go`
- Create: `backend/internal/chat/list_direct_message_history/postgres/repository.go`
- Create: `backend/internal/chat/list_direct_message_history/postgres/pool_database.go`
- Create: `backend/internal/database/migrate/migrations/0019_create_direct_message_messages_history_index.sql`

- [x] **Step 1: Implement input validation and the `limit + 1` cursor result**

```go
type Input struct { ActorID, DirectMessageID, Before string; Limit int }
func (service Service) List(ctx context.Context, input Input) (Result, error) {
    if !validUUID(input.ActorID) || !validUUID(input.DirectMessageID) || (input.Before != "" && !validUUID(input.Before)) || input.Limit < 1 || input.Limit > 100 { return Result{}, ErrInvalidInput }
    messages, err := service.store.List(ctx, Request{Input: input})
    if errors.Is(err, ErrDirectMessageUnavailable) { return Result{}, ErrDirectMessageUnavailable }
    if err != nil { return Result{}, fmt.Errorf("list direct message history: %w", err) }
    result := Result{Messages: messages}
    if len(result.Messages) > input.Limit { result.Messages = result.Messages[:input.Limit]; result.NextCursor = result.Messages[len(result.Messages)-1].ID }
    return result, nil
}
```

- [x] **Step 2: Guard both repository operations with participant-only membership**

```sql
WITH readable_pair AS (
    SELECT dm.id FROM direct_messages dm
    WHERE dm.id = $1
      AND $2::uuid IN (dm.participant_one_id, dm.participant_two_id)
), cursor AS (
    SELECT m.created_at, m.id FROM direct_message_messages m
    WHERE m.id = $3::uuid AND m.direct_message_id = (SELECT id FROM readable_pair)
)
SELECT m.id::text, m.direct_message_id::text, m.author_id::text, m.client_message_id::text,
       CASE WHEN m.deleted_at IS NULL THEN m.body ELSE '' END, m.created_at, m.edited_at, m.revision, m.deleted_at IS NOT NULL
FROM direct_message_messages m
WHERE m.direct_message_id = (SELECT id FROM readable_pair)
  AND ($3::uuid IS NULL OR (m.created_at, m.id) < (SELECT created_at, id FROM cursor))
ORDER BY m.created_at DESC, m.id DESC
LIMIT $4
```

The preceding availability query uses the same membership predicate. Neither query checks `blocked_at`: this preserves the specified post-ban history for the other participant. Role is not an input to service or SQL.

- [x] **Step 3: Add the pagination index**

```sql
CREATE INDEX IF NOT EXISTS direct_message_messages_history_idx
    ON direct_message_messages (direct_message_id, created_at DESC, id DESC);
```

- [x] **Step 4: Run focused tests to verify pass**

Run: `go test ./internal/chat/list_direct_message_history/... ./internal/database/migrate`

Expected: PASS with bounds checks, participant-only queries, deleted marker projection, and the embedded index migration.

### Task 3: Publish the authenticated GET contract and traceability

**Files:**
- Create: `backend/internal/chat/list_direct_message_history/api/http_handler.go`
- Modify: `backend/cmd/api/chat_routes.go`
- Modify: `contracts/openapi.yaml`
- Modify: `scripts/verify-contracts.ps1`
- Modify: `TODO.md`

- [x] **Step 1: Implement the session-protected page endpoint**

```go
principal, ok := sessionapi.PrincipalFrom(request.Context())
if !ok { writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось загрузить личные сообщения"); return }
result, err := lister.List(request.Context(), listdirectmessagehistory.Input{ActorID: principal.AccountID, DirectMessageID: request.PathValue("directMessageID"), Before: request.URL.Query().Get("before"), Limit: limit})
```

Register exactly:

```go
mux.Handle("GET /api/v1/direct-messages/{directMessageID}/messages", sessionapi.Require(sessions)(listdirectmessagehistoryapi.NewHandler(directMessageHistory)))
```

- [x] **Step 2: Add the OpenAPI response shape and contract assertion**

```json
"/api/v1/direct-messages/{directMessageID}/messages": {
  "get": { "operationId": "listDirectMessageHistory", "description": "Authenticated DM participant only; administrator role grants no exception. History remains available to the other participant after a block." }
}
```

Add `DirectMessageMessageHistoryItem` and `DirectMessageMessagePage` schemas, with `body`, `edited_at`, `revision`, and `deleted` so clients receive a marker rather than deleted content.

- [x] **Step 3: Update the T-041 traceability statement**

```md
`GET /direct-messages/{id}/messages` supplies a `limit`/`before` cursor page only when the caller belongs to the canonical pair. Membership is checked in the query that returns rows, administrator role is absent from the service/SQL, and the history query intentionally does not reject an already blocked counterpart.
```

- [x] **Step 4: Format and run native validation**

Run: `gofmt -w` for changed Go files, `go test ./...`, `go vet ./...`, `go build -o "$env:TEMP\voice-platform-api-dm-history-check.exe" ./cmd/api`, `scripts/verify-contracts.ps1`, `scripts/verify-spec-traceability.ps1`, and `git diff --check`.

Expected: all checks pass. No production response logs a DM body, no route receives a role-based exception, and no binary is written in the workspace.

## Self-review

Coverage: REQ-DM-01 and REQ-SECURITY-02 are covered for the history API’s participant-only ACL, post-ban history behavior, pagination, and deleted-content projection. Reply preview, editing, deletion mutation, events, counters, notifications, attachments, and search remain outside this one leaf.

Placeholder scan: no placeholders. Type names and the `List` signature are consistent across the service, repository, route, and tests.
