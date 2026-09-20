# Direct-message Soft Delete Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let only the author of a DM soft-delete their message while retaining its identity and reply target.

**Architecture:** Add a dedicated `delete_direct_message` leaf. A single SQL statement derives the caller’s canonical pair, then changes only a matching author-owned, non-deleted row to an empty body, `deleted_at`, and incremented revision. No actor role enters the service or SQL; history’s existing deleted projection continues to yield an ID/revision/deleted marker and no body.

**Tech Stack:** Go 1.26, PostgreSQL/pgx, net/http, OpenAPI 3.1, Go testing.

---

### Task 1: Write failing author-only soft-delete tests

**Files:**
- Create: `backend/internal/chat/delete_direct_message/service_test.go`
- Create: `backend/internal/chat/delete_direct_message/postgres/repository_test.go`
- Create: `backend/internal/chat/delete_direct_message/api/http_handler_test.go`

- [x] **Step 1: Add service tests for valid IDs, invalid input, and denied result preservation**

```go
result, err := New(store).Delete(context.Background(), Input{ActorID: actorID, DirectMessageID: directMessageID, MessageID: messageID})
if err != nil || result.Revision != 2 || store.request.ActorID != actorID { t.Fatalf("result=%#v request=%#v error=%v", result, store.request, err) }
_, err = New(&fakeStore{err: ErrDeleteDenied}).Delete(context.Background(), Input{ActorID: actorID, DirectMessageID: directMessageID, MessageID: messageID})
if !errors.Is(err, ErrDeleteDenied) { t.Fatalf("error=%v", err) }
```

- [x] **Step 2: Add repository tests for marker update, pair membership, author, and no role bypass**

```go
for _, fragment := range []string{"SET body = ''", "revision = message.revision + 1", "$3::uuid IN (dm.participant_one_id, dm.participant_two_id)", "message.direct_message_id = writable_pair.id", "message.author_id = $3", "message.deleted_at IS NULL"} {
    if !strings.Contains(database.statement, fragment) { t.Fatalf("missing %q", fragment) }
}
if strings.Contains(database.statement, "ADMINISTRATOR") || strings.Contains(database.statement, "blocked_at") { t.Fatalf("DM deletion must not have role bypass or require unblocked counterpart") }
```

`pgx.ErrNoRows` maps to `ErrDeleteDenied`, covering foreign DM, non-author, already-deleted, and missing message without revealing which condition failed.

- [x] **Step 3: Add a DELETE handler test with an administrator principal**

```go
request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: actorID, Role: "ADMINISTRATOR"}))
handler.ServeHTTP(recorder, request)
if recorder.Code != http.StatusNoContent || input.ActorID != actorID || input.DirectMessageID == "" || input.MessageID == "" { t.Fatalf("status=%d input=%#v", recorder.Code, input) }
```

- [x] **Step 4: Run focused tests to verify failure**

Run: `go test ./internal/chat/delete_direct_message/...`

Expected: FAIL because the DM-delete capability does not exist.

### Task 2: Implement atomic marker deletion

**Files:**
- Create: `backend/internal/chat/delete_direct_message/service.go`
- Create: `backend/internal/chat/delete_direct_message/postgres/repository.go`
- Create: `backend/internal/chat/delete_direct_message/postgres/pool_database.go`

- [x] **Step 1: Validate three UUIDs and normalize denial**

```go
type Input struct { ActorID, DirectMessageID, MessageID string }
func (service Service) Delete(ctx context.Context, input Input) (Result, error) {
    if !validUUID(input.ActorID) || !validUUID(input.DirectMessageID) || !validUUID(input.MessageID) { return Result{}, ErrInvalidInput }
    result, err := service.store.Delete(ctx, Request{Input: input})
    if errors.Is(err, ErrDeleteDenied) { return Result{}, ErrDeleteDenied }
    if err != nil { return Result{}, fmt.Errorf("delete direct message: %w", err) }
    return result, nil
}
```

- [x] **Step 2: Apply the marker update under one pair-and-author predicate**

```sql
WITH writable_pair AS (
    SELECT dm.id FROM direct_messages dm
    WHERE dm.id = $2
      AND $3::uuid IN (dm.participant_one_id, dm.participant_two_id)
)
UPDATE direct_message_messages AS message
SET body = '', deleted_at = now(), revision = message.revision + 1
FROM writable_pair
WHERE message.id = $1
  AND message.direct_message_id = writable_pair.id
  AND message.author_id = $3
  AND message.deleted_at IS NULL
RETURNING message.id::text, message.direct_message_id::text, message.revision, message.deleted_at
```

No DELETE statement, cascading action, role, or `blocked_at` predicate is permitted.

- [x] **Step 3: Run focused tests to verify pass**

Run: `go test ./internal/chat/delete_direct_message/...`

Expected: PASS with retained identifiers, body marker update, author-only same-pair ACL, and denial normalization.

### Task 3: Publish the DELETE contract and traceability

**Files:**
- Create: `backend/internal/chat/delete_direct_message/api/http_handler.go`
- Modify: `backend/cmd/api/chat_routes.go`
- Modify: `contracts/openapi.yaml`
- Modify: `scripts/verify-contracts.ps1`
- Modify: `TODO.md`

- [x] **Step 1: Implement and register session-protected DELETE**

```go
_, err := deleter.Delete(request.Context(), deletedirectmessage.Input{ActorID: principal.AccountID, DirectMessageID: request.PathValue("directMessageID"), MessageID: request.PathValue("messageID")})
```

```go
mux.Handle("DELETE /api/v1/direct-messages/{directMessageID}/messages/{messageID}", sessionapi.Require(sessions)(deletedirectmessageapi.NewHandler(directMessageDeleter)))
```

- [x] **Step 2: Add the nondisclosing 204/404 OpenAPI contract and verifier assertion**

```json
"delete": {
  "operationId": "deleteDirectMessage",
  "description": "Authenticated DM author only. Sets a deletion marker and preserves ID/revision for history and replies; administrator role grants no exception."
}
```

- [x] **Step 3: Record the T-041 deletion boundary and run native validation**

```md
DELETE DM never physically removes a row; only its author can atomically clear body and set deleted marker, so reply/history retain the ID and new revision without an admin exception.
```

Run: `gofmt -w` for changed Go files, `go test ./...`, `go vet ./...`, `go build -o "$env:TEMP\voice-platform-api-dm-delete-check.exe" ./cmd/api`, `scripts/verify-contracts.ps1`, `scripts/verify-spec-traceability.ps1`, and `git diff --check`.

Expected: all checks pass without a workspace binary, physical message delete, or role bypass.

## Self-review

Coverage: this leaf implements DM author deletion and deleted-marker retention from REQ-CHAT-01 while preserving REQ-DM-01/REQ-SECURITY-02 boundaries. Reply rendering, events, counters, notifications, attachments, physical file cleanup, and search remain separate leaves.

Placeholder scan: no placeholders. Input, result, denial, and deleted marker are consistent through service, repository, handler, and contract.
