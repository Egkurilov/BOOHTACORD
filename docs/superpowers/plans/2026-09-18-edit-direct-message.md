# Direct-message Edit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a DM author atomically revise their own non-deleted message only when the version they saw is current.

**Architecture:** Implement a dedicated `edit_direct_message` leaf that mirrors the text-message edit shape but derives authorization from the canonical DM pair. The single SQL update checks participant membership, target DM, author, deletion state, and expected revision; zero updated rows map to one nondisclosing conflict. It intentionally does not require the other participant to be unblocked, because the product only prohibits new sends after block while retaining history.

**Tech Stack:** Go 1.26, PostgreSQL/pgx, net/http, OpenAPI 3.1, Go testing.

---

### Task 1: Write failing author/revision tests

**Files:**
- Create: `backend/internal/chat/edit_direct_message/service_test.go`
- Create: `backend/internal/chat/edit_direct_message/postgres/repository_test.go`
- Create: `backend/internal/chat/edit_direct_message/api/http_handler_test.go`

- [x] **Step 1: Add service tests for revision forwarding, unsafe input, and conflict preservation**

```go
result, err := New(store).Edit(context.Background(), Input{ActorID: actorID, DirectMessageID: directMessageID, MessageID: messageID, Body: "исправлено", ExpectedRevision: 1})
if err != nil || store.request.ExpectedRevision != 1 || result.Revision != 2 { t.Fatalf("result=%#v request=%#v error=%v", result, store.request, err) }
_, err = New(&fakeStore{err: ErrConflict}).Edit(context.Background(), Input{ActorID: actorID, DirectMessageID: directMessageID, MessageID: messageID, Body: "исправлено", ExpectedRevision: 1})
if !errors.Is(err, ErrConflict) { t.Fatalf("error=%v", err) }
```

- [x] **Step 2: Add repository tests for same-DM participant author checks and conflict mapping**

```go
for _, fragment := range []string{"$3::uuid IN (dm.participant_one_id, dm.participant_two_id)", "message.direct_message_id = writable_pair.id", "message.author_id = $3", "message.deleted_at IS NULL", "message.revision = $5", "revision = message.revision + 1"} {
    if !strings.Contains(database.statement, fragment) { t.Fatalf("missing %q", fragment) }
}
if strings.Contains(database.statement, "blocked_at") { t.Fatalf("editing retained history must not require an unblocked counterpart") }
```

`pgx.ErrNoRows` must map to one `ErrConflict`, covering foreign DM, non-author, deleted, and stale revision without disclosing which condition failed.

- [x] **Step 3: Add a handler test that passes an administrator principal as actor only**

```go
request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: actorID, Role: "ADMINISTRATOR"}))
handler.ServeHTTP(recorder, request)
if recorder.Code != http.StatusOK || input.ActorID != actorID || input.ExpectedRevision != 1 || !strings.Contains(recorder.Body.String(), `"revision":2`) { t.Fatalf("status=%d input=%#v", recorder.Code, input) }
```

- [x] **Step 4: Run focused tests to verify failure**

Run: `go test ./internal/chat/edit_direct_message/...`

Expected: FAIL because the DM-edit capability does not exist.

### Task 2: Implement atomic author-only edit

**Files:**
- Create: `backend/internal/chat/edit_direct_message/service.go`
- Create: `backend/internal/chat/edit_direct_message/postgres/repository.go`
- Create: `backend/internal/chat/edit_direct_message/postgres/pool_database.go`

- [x] **Step 1: Implement input validation and a nondisclosing conflict**

```go
type Input struct { ActorID, DirectMessageID, MessageID, Body string; ExpectedRevision int }
func (service Service) Edit(ctx context.Context, input Input) (Result, error) {
    if !validUUID(input.ActorID) || !validUUID(input.DirectMessageID) || !validUUID(input.MessageID) || input.ExpectedRevision < 1 || !utf8.ValidString(input.Body) || utf8.RuneCountInString(input.Body) > 8000 || input.Body == "" || strings.ContainsRune(input.Body, '\x00') { return Result{}, ErrInvalidInput }
    result, err := service.store.Edit(ctx, Request{Input: input})
    if errors.Is(err, ErrConflict) { return Result{}, ErrConflict }
    if err != nil { return Result{}, fmt.Errorf("edit direct message: %w", err) }
    return result, nil
}
```

- [x] **Step 2: Use one UPDATE guarded by pair membership, author, state, and revision**

```sql
WITH writable_pair AS (
    SELECT dm.id FROM direct_messages dm
    WHERE dm.id = $2
      AND $3::uuid IN (dm.participant_one_id, dm.participant_two_id)
)
UPDATE direct_message_messages AS message
SET body = $4, edited_at = now(), revision = message.revision + 1
FROM writable_pair
WHERE message.id = $1
  AND message.direct_message_id = writable_pair.id
  AND message.author_id = $3
  AND message.deleted_at IS NULL
  AND message.revision = $5
RETURNING message.id::text, message.direct_message_id::text, message.author_id::text, message.client_message_id::text,
          message.body, COALESCE(message.reply_to_id::text, ''), message.revision, message.created_at, message.edited_at
```

No role or `blocked_at` condition is passed. `pgx.ErrNoRows` becomes `ErrConflict`.

- [x] **Step 3: Run focused tests to verify pass**

Run: `go test ./internal/chat/edit_direct_message/...`

Expected: PASS with author-and-revision guard, same-pair predicate, deleted rejection, and conflict normalization.

### Task 3: Publish the PATCH contract and traceability

**Files:**
- Create: `backend/internal/chat/edit_direct_message/api/http_handler.go`
- Modify: `backend/cmd/api/chat_routes.go`
- Modify: `contracts/openapi.yaml`
- Modify: `scripts/verify-contracts.ps1`
- Modify: `TODO.md`

- [x] **Step 1: Implement and register the session-protected PATCH route**

```go
result, err := editor.Edit(request.Context(), editdirectmessage.Input{ActorID: principal.AccountID, DirectMessageID: request.PathValue("directMessageID"), MessageID: request.PathValue("messageID"), Body: body.Body, ExpectedRevision: body.ExpectedRevision})
```

```go
mux.Handle("PATCH /api/v1/direct-messages/{directMessageID}/messages/{messageID}", sessionapi.Require(sessions)(editdirectmessageapi.NewHandler(directMessageEditor)))
```

- [x] **Step 2: Add OpenAPI request/result schemas and the verifier assertion**

```json
"DirectMessageMessageEditRequest": {
  "required": ["body", "expected_revision"],
  "properties": { "body": { "type": "string", "minLength": 1, "maxLength": 8000 }, "expected_revision": { "type": "integer", "minimum": 1 } }
}
```

The 409 description stays nondisclosing: author mismatch, stale revision, deletion, absent DM, and foreign target are intentionally indistinguishable.

- [x] **Step 3: Update T-041 and run native validation**

```md
PATCH DM edit accepts only author plus expected revision in the same atomic statement; role is absent and all zero-row ACL/state causes become one conflict.
```

Run: `gofmt -w` for changed Go files, `go test ./...`, `go vet ./...`, `go build -o "$env:TEMP\voice-platform-api-dm-edit-check.exe" ./cmd/api`, `scripts/verify-contracts.ps1`, `scripts/verify-spec-traceability.ps1`, and `git diff --check`.

Expected: all checks pass without a workspace binary or administrator bypass.

## Self-review

Coverage: this leaf implements DM author editing and optimistic concurrency from REQ-CHAT-01, while retaining REQ-DM-01/REQ-SECURITY-02 participant-only boundaries. Deletion, reply rendering, events, counters, notifications, attachments, and search remain separate leaves.

Placeholder scan: no placeholders. Input, result, revision, and conflict names match across service, repository, handler, and contract.
