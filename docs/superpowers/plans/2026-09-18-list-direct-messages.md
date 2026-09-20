# Direct-message List Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give an authenticated account a navigation list of only its own canonical 1:1 direct-message pairs.

**Architecture:** Add an isolated read-only Go leaf. The repository derives the other participant directly from the canonical pair and joins only that account for its display name; the input has no role and the SQL filters on the caller’s ID. The endpoint intentionally includes a pre-existing pair after its counterpart is blocked so the history route remains reachable, while opening and sending remain governed by their stricter active-account rules.

**Tech Stack:** Go 1.26, PostgreSQL/pgx, net/http, OpenAPI 3.1, Go testing.

---

### Task 1: Write failing list and ACL tests

**Files:**
- Create: `backend/internal/chat/list_direct_messages/service_test.go`
- Create: `backend/internal/chat/list_direct_messages/postgres/repository_test.go`
- Create: `backend/internal/chat/list_direct_messages/api/http_handler_test.go`

- [x] **Step 1: Add a service test for valid caller forwarding and malformed caller rejection**

```go
result, err := New(store).List(context.Background(), Input{ActorID: actorID})
if err != nil || len(result.DirectMessages) != 1 || store.request.ActorID != actorID { t.Fatalf("result=%#v request=%#v error=%v", result, store.request, err) }
_, err = New(&fakeStore{}).List(context.Background(), Input{ActorID: "not-a-uuid"})
if !errors.Is(err, ErrInvalidInput) { t.Fatalf("error=%v", err) }
```

- [x] **Step 2: Add a repository test for caller-only pair selection and post-ban history reachability**

```go
result, err := New(database).List(context.Background(), Request{Input: Input{ActorID: actorID}})
if err != nil || result[0].OtherParticipantDisplayName != "Собеседник" { t.Fatalf("result=%#v error=%v", result, err) }
for _, fragment := range []string{"participant_one_id = $1::uuid", "participant_two_id = $1::uuid", "JOIN users account ON account.id = pair.other_participant_id"} {
    if !strings.Contains(database.statement, fragment) { t.Fatalf("missing %q", fragment) }
}
if strings.Contains(database.statement, "blocked_at") { t.Fatalf("list must preserve the other participant’s history route after a block") }
```

- [x] **Step 3: Add an authenticated handler test using an administrator principal**

```go
request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: actorID, Role: "ADMINISTRATOR"}))
handler.ServeHTTP(recorder, request)
if recorder.Code != http.StatusOK || input.ActorID != actorID || !strings.Contains(recorder.Body.String(), `"other_participant_display_name":"Собеседник"`) { t.Fatalf("status=%d input=%#v", recorder.Code, input) }
```

- [x] **Step 4: Run focused tests to verify the expected failure**

Run: `go test ./internal/chat/list_direct_messages/...`

Expected: FAIL because the capability package does not exist.

### Task 2: Implement the participant-only navigation list

**Files:**
- Create: `backend/internal/chat/list_direct_messages/service.go`
- Create: `backend/internal/chat/list_direct_messages/postgres/repository.go`
- Create: `backend/internal/chat/list_direct_messages/postgres/pool_database.go`

- [x] **Step 1: Implement UUID validation and typed result**

```go
type Input struct{ ActorID string }
type DirectMessage struct { ID, OtherParticipantID, OtherParticipantDisplayName string; CreatedAt time.Time }
type Result struct{ DirectMessages []DirectMessage }
func (service Service) List(ctx context.Context, input Input) (Result, error) {
    if !validUUID(input.ActorID) { return Result{}, ErrInvalidInput }
    directMessages, err := service.store.List(ctx, Request{Input: input})
    if err != nil { return Result{}, fmt.Errorf("list direct messages: %w", err) }
    return Result{DirectMessages: directMessages}, nil
}
```

- [x] **Step 2: Use the caller ID to derive, and only then expose, the other participant**

```sql
WITH pair AS (
    SELECT dm.id, dm.participant_two_id AS other_participant_id, dm.created_at
    FROM direct_messages dm WHERE dm.participant_one_id = $1::uuid
    UNION ALL
    SELECT dm.id, dm.participant_one_id AS other_participant_id, dm.created_at
    FROM direct_messages dm WHERE dm.participant_two_id = $1::uuid
)
SELECT pair.id::text, pair.other_participant_id::text, account.display_name, pair.created_at
FROM pair
JOIN users account ON account.id = pair.other_participant_id
ORDER BY pair.created_at DESC, pair.id DESC
```

Do not filter on `blocked_at` and do not accept role input. The former lets the remaining account navigate to retained history; the latter prevents an administrative read bypass.

- [x] **Step 3: Run focused tests to verify pass**

Run: `go test ./internal/chat/list_direct_messages/...`

Expected: PASS with caller validation, canonical-pair-only SQL, display-name DTO, and no block/role exception.

### Task 3: Publish the authenticated GET contract and traceability

**Files:**
- Create: `backend/internal/chat/list_direct_messages/api/http_handler.go`
- Modify: `backend/cmd/api/chat_routes.go`
- Modify: `contracts/openapi.yaml`
- Modify: `scripts/verify-contracts.ps1`
- Modify: `TODO.md`

- [x] **Step 1: Implement and register the GET route**

```go
principal, ok := sessionapi.PrincipalFrom(request.Context())
if !ok { writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось загрузить личные диалоги"); return }
result, err := lister.List(request.Context(), listdirectmessages.Input{ActorID: principal.AccountID})
```

```go
mux.Handle("GET /api/v1/direct-messages", sessionapi.Require(sessions)(listdirectmessagesapi.NewHandler(directMessages)))
```

- [x] **Step 2: Define the response contract and assert its route**

```json
"DirectMessageList": {
  "type": "object",
  "required": ["direct_messages"],
  "properties": { "direct_messages": { "type": "array", "items": { "$ref": "#/components/schemas/DirectMessageListItem" } } }
}
```

The `GET /api/v1/direct-messages` operation documents participant-only visibility, no administrative exception, and preservation of a pre-existing pair after block.

- [x] **Step 3: State the new list ACL in T-041**

```md
`GET /direct-messages` returns only canonical pairs containing caller and only the paired account’s display name. It does not accept role or filter an existing pair on block state, preserving navigation to the retained history.
```

- [x] **Step 4: Format and run native validation**

Run: `gofmt -w` for changed Go files, `go test ./...`, `go vet ./...`, `go build -o "$env:TEMP\voice-platform-api-dm-list-check.exe" ./cmd/api`, `scripts/verify-contracts.ps1`, `scripts/verify-spec-traceability.ps1`, and `git diff --check`.

Expected: all checks pass. The handler has no role parameter, and no production log includes a DM ID or display name.

## Self-review

Coverage: this leaf covers the navigation-list portion of REQ-DM-01 and preserves REQ-SECURITY-02’s participant-only boundary. It does not add friends, cross-guild discovery, group DM, reply/edit/delete, events, counters, notifications, attachments, or search.

Placeholder scan: no placeholders. `Input`, `Request`, `DirectMessage`, `Result`, and `List` are consistent across all tasks.
