# Direct-message Replies Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow a new direct-message post to reference only an existing message in the same direct-message pair.

**Architecture:** Extend direct-message storage with a nullable self-reference. The existing send leaf validates a supplied UUID and atomically verifies the reply target’s `direct_message_id` within the same CTE that enforces membership and active send participants. History exposes only the reply ID, never a copied reply body, so a deleted original remains represented by the history marker and no preview adds a second ACL surface.

**Tech Stack:** Go 1.26, PostgreSQL/pgx, net/http, embedded migrations, OpenAPI 3.1, Go testing.

---

### Task 1: Add failing reply contract, migration, and ACL tests

**Files:**
- Modify: `backend/internal/chat/send_direct_message/service_test.go`
- Modify: `backend/internal/chat/send_direct_message/postgres/repository_test.go`
- Modify: `backend/internal/chat/send_direct_message/api/http_handler_test.go`
- Modify: `backend/internal/chat/list_direct_message_history/postgres/repository_test.go`
- Modify: `backend/internal/chat/list_direct_message_history/api/http_handler_test.go`
- Modify: `backend/internal/database/migrate/run_test.go`

- [x] **Step 1: Make the service reject malformed reply IDs and forward a valid ID**

```go
_, err := New(&fakeStore{}).Send(context.Background(), Input{ActorID: senderID, DirectMessageID: directMessageID, ClientMessageID: clientMessageID, ReplyToID: "not-a-uuid", Body: "Привет"})
if !errors.Is(err, ErrInvalidInput) { t.Fatalf("error=%v", err) }
result, err := New(store).Send(context.Background(), Input{ActorID: senderID, DirectMessageID: directMessageID, ClientMessageID: clientMessageID, ReplyToID: replyID, Body: "Привет"})
if err != nil || result.ReplyToID != replyID || store.request.ReplyToID != replyID { t.Fatalf("result=%#v request=%#v error=%v", result, store.request, err) }
```

- [x] **Step 2: Require the SQL assertion that a reply belongs to the same active pair**

```go
for _, fragment := range []string{"$6::uuid IS NULL OR EXISTS", "reply.direct_message_id = active_pair.id", "COALESCE(reply_to_id::text, '')"} {
    if !strings.Contains(database.statement, fragment) { t.Fatalf("missing %q", fragment) }
}
```

The test fixture includes a `reply_to_id` scan value and preserves the existing no-role test boundary.

- [x] **Step 3: Require reply IDs in send JSON and history JSON, plus the new embedded migration**

```go
request := httptest.NewRequest(http.MethodPost, path, strings.NewReader(`{"client_message_id":"...","reply_to_id":"55555555-5555-4555-8555-555555555555","body":"Привет"}`))
if input.ReplyToID == "" || !strings.Contains(recorder.Body.String(), `"reply_to_id":"55555555-5555-4555-8555-555555555555"`) { t.Fatalf("input=%#v body=%q", input, recorder.Body.String()) }
if len(executor.statements) != 20 || !strings.Contains(executor.statements[19], "reply_to_id UUID REFERENCES direct_message_messages") { t.Fatalf("statements=%#v", executor.statements) }
```

- [x] **Step 4: Run focused tests to verify failure**

Run: `go test ./internal/chat/send_direct_message/... ./internal/chat/list_direct_message_history/... ./internal/database/migrate`

Expected: FAIL because direct-message replies do not yet exist.

### Task 2: Implement the same-conversation reply invariant

**Files:**
- Create: `backend/internal/database/migrate/migrations/0020_add_direct_message_reply_to_id.sql`
- Modify: `backend/internal/chat/send_direct_message/service.go`
- Modify: `backend/internal/chat/send_direct_message/postgres/repository.go`
- Modify: `backend/internal/chat/send_direct_message/api/http_handler.go`
- Modify: `backend/internal/chat/list_direct_message_history/service.go`
- Modify: `backend/internal/chat/list_direct_message_history/postgres/repository.go`
- Modify: `backend/internal/chat/list_direct_message_history/api/http_handler.go`

- [x] **Step 1: Add the nullable FK without cascade deletion**

```sql
ALTER TABLE direct_message_messages
    ADD COLUMN IF NOT EXISTS reply_to_id UUID REFERENCES direct_message_messages(id) ON DELETE RESTRICT;
```

- [x] **Step 2: Keep reply target verification in the existing guarded insert statement**

```sql
WITH active_pair AS (...), inserted AS (
    INSERT INTO direct_message_messages (id, direct_message_id, author_id, client_message_id, body, reply_to_id)
    SELECT $1::uuid, active_pair.id, $3::uuid, $4::uuid, $5, $6::uuid
    FROM active_pair
    WHERE $6::uuid IS NULL OR EXISTS (
        SELECT 1 FROM direct_message_messages reply
        WHERE reply.id = $6::uuid AND reply.direct_message_id = active_pair.id
    )
    ON CONFLICT (author_id, direct_message_id, client_message_id) DO UPDATE SET client_message_id = EXCLUDED.client_message_id
    RETURNING id::text, direct_message_id::text, author_id::text, client_message_id::text, body, COALESCE(reply_to_id::text, ''), revision, created_at
)
SELECT * FROM inserted
```

The active-pair CTE continues to enforce caller membership and both accounts unblocked for sending. A cross-DM reply produces no insert and maps to the existing nondisclosing unavailable result.

- [x] **Step 3: Carry only `reply_to_id` through send and history DTOs**

```go
type Input struct { ActorID, DirectMessageID, ClientMessageID, ReplyToID, Body string }
type Message struct { ID, DirectMessageID, AuthorID, ClientMessageID, Body, ReplyToID string /* timestamps and state follow */ }
```

History selects `COALESCE(m.reply_to_id::text, '')` and JSON omits an empty value. No query reads original message body as a reply preview.

- [x] **Step 4: Run focused tests to verify pass**

Run: `go test ./internal/chat/send_direct_message/... ./internal/chat/list_direct_message_history/... ./internal/database/migrate`

Expected: PASS with malformed-ID rejection, same-pair SQL, reply serialization, deleted-message-safe history, and the embedded migration.

### Task 3: Publish contract and traceability

**Files:**
- Modify: `contracts/openapi.yaml`
- Modify: `scripts/verify-contracts.ps1`
- Modify: `TODO.md`

- [x] **Step 1: Add optional reply fields to all direct-message create/read schemas**

```json
"reply_to_id": { "type": "string", "format": "uuid", "description": "Must identify a message in this same direct-message pair." }
```

`DirectMessageMessage` and `DirectMessageMessageHistoryItem` keep the field optional, so no-reply messages remain compatible.

- [x] **Step 2: Assert reply contract availability and document the T-041 boundary**

```powershell
if ($null -eq $openApi.components.schemas.DirectMessageMessageCreateRequest.properties.reply_to_id) {
    throw 'DM contract must define reply_to_id for direct-message creation.'
}
```

```md
DM reply preserves only target ID and atomically accepts it only when target and new message are in the same canonical pair; no reply preview creates a separate content-read path.
```

- [x] **Step 3: Format and run native validation**

Run: `gofmt -w` for changed Go files, `go test ./...`, `go vet ./...`, `go build -o "$env:TEMP\voice-platform-api-dm-reply-check.exe" ./cmd/api`, `scripts/verify-contracts.ps1`, `scripts/verify-spec-traceability.ps1`, and `git diff --check`.

Expected: all checks pass without a workspace binary or a role-based DM exception.

## Self-review

Coverage: this leaf implements REQ-CHAT-01’s same-conversation reply invariant for DM and the DM ACL portion of REQ-SECURITY-02. Editing/deleting messages, reply rendering, events, counters, notifications, attachments, and search remain separate leaves.

Placeholder scan: no placeholders. `ReplyToID` has the same type and spelling across storage, service, HTTP, history, and OpenAPI.
