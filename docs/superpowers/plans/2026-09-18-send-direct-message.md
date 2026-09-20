# Send Direct Message Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow either participant of an existing active 1:1 DM to create one idempotent text message, while banning either participant stops new sends.

**Architecture:** A DM-message table has the same message invariants as common-chat messages, scoped by direct-message ID instead of channel. The insertion CTE verifies caller membership and both `users.blocked_at IS NULL` in the same SQL statement before insertion; it holds no role parameter. HTTP receives body/client ID and binds author plus conversation ID from its session and route.

**Tech Stack:** Go 1.26, PostgreSQL/pgx, net/http, embedded migrations, OpenAPI 3.1, Go testing.

---

### Task 1: Add DM-message storage and write-only ACL

**Status:** Complete — migration, service, and repository tests pass.

**Files:**
- Create: `backend/internal/database/migrate/migrations/0018_create_direct_message_messages.sql`
- Modify: `backend/internal/database/migrate/run_test.go`
- Create: `backend/internal/chat/send_direct_message/service.go`
- Create: `backend/internal/chat/send_direct_message/id.go`
- Create: `backend/internal/chat/send_direct_message/service_test.go`
- Create: `backend/internal/chat/send_direct_message/postgres/repository.go`
- Create: `backend/internal/chat/send_direct_message/postgres/pool_database.go`
- Create: `backend/internal/chat/send_direct_message/postgres/repository_test.go`

- [x] **Step 1: Write failing service, repository, and migration tests**

```go
_, err := service.Send(context.Background(), Input{ActorID: actorID, DirectMessageID: dmID, ClientMessageID: clientID, Body: ""})
if !errors.Is(err, ErrInvalidInput) || store.called { t.Fatalf("empty message was persisted") }
for _, fragment := range []string{"author_id = $3", "blocked_at IS NULL", "ON CONFLICT (author_id, direct_message_id, client_message_id)"} {
  if !strings.Contains(database.statement, fragment) { t.Fatalf("missing %q", fragment) }
}
```

- [x] **Step 2: Run focused tests to verify failure**

Run: `go test ./internal/chat/send_direct_message/... ./internal/database/migrate`

Expected: FAIL because DM-message storage and write leaf do not exist.

- [x] **Step 3: Implement the migration, input validation, and atomic insert**

```sql
CREATE TABLE IF NOT EXISTS direct_message_messages (
    id UUID PRIMARY KEY,
    direct_message_id UUID NOT NULL REFERENCES direct_messages(id) ON DELETE RESTRICT,
    author_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    client_message_id UUID NOT NULL,
    body TEXT NOT NULL CHECK (char_length(body) BETWEEN 1 AND 8000),
    revision INTEGER NOT NULL DEFAULT 1 CHECK (revision > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    edited_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT direct_message_messages_author_client_unique UNIQUE (author_id, direct_message_id, client_message_id)
);
```

```sql
WITH readable_pair AS (
    SELECT dm.id FROM direct_messages dm
    WHERE dm.id = $2 AND $3::uuid IN (dm.participant_one_id, dm.participant_two_id)
      AND EXISTS (SELECT 1 FROM users WHERE id = dm.participant_one_id AND blocked_at IS NULL)
      AND EXISTS (SELECT 1 FROM users WHERE id = dm.participant_two_id AND blocked_at IS NULL)
), inserted AS (
    INSERT INTO direct_message_messages (id, direct_message_id, author_id, client_message_id, body)
    SELECT $1::uuid, readable_pair.id, $3::uuid, $4::uuid, $5 FROM readable_pair
    ON CONFLICT (author_id, direct_message_id, client_message_id) DO UPDATE SET client_message_id = EXCLUDED.client_message_id
    RETURNING id::text, direct_message_id::text, author_id::text, client_message_id::text, body, revision, created_at
)
SELECT * FROM inserted
```

- [x] **Step 4: Run focused tests to verify pass**

Run: `go test ./internal/chat/send_direct_message/... ./internal/database/migrate`

Expected: PASS with validation, membership/block predicate, idempotency, and embedded migration checks.

### Task 2: Publish the authenticated send endpoint and contract

**Status:** Complete — handler and contract checks pass.

**Files:**
- Create: `backend/internal/chat/send_direct_message/api/http_handler.go`
- Create: `backend/internal/chat/send_direct_message/api/http_handler_test.go`
- Modify: `backend/cmd/api/chat_routes.go`
- Modify: `contracts/openapi.yaml`
- Modify: `scripts/verify-contracts.ps1`

- [x] **Step 1: Write a failing handler test**

```go
request := httptest.NewRequest(http.MethodPost, "/api/v1/direct-messages/33333333-3333-4333-8333-333333333333/messages", strings.NewReader(`{"client_message_id":"44444444-4444-4444-8444-444444444444","body":"Привет"}`))
request.SetPathValue("directMessageID", "33333333-3333-4333-8333-333333333333")
request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "11111111-1111-4111-8111-111111111111", Role: "ADMINISTRATOR"}))
handler.ServeHTTP(recorder, request)
if recorder.Code != http.StatusCreated || input.ActorID == "" || input.DirectMessageID == "" { t.Fatalf("status=%d input=%#v", recorder.Code, input) }
```

- [x] **Step 2: Run the handler test to verify failure**

Run: `go test ./internal/chat/send_direct_message/api`

Expected: FAIL because the send handler does not exist.

- [x] **Step 3: Implement route and OpenAPI contract**

```go
mux.Handle("POST /api/v1/direct-messages/{directMessageID}/messages", sessionapi.Require(sessions)(senddirectmessageapi.NewHandler(directMessageSender)))
```

```yaml
"/api/v1/direct-messages/{directMessageID}/messages":
  post:
    operationId: sendDirectMessage
    description: Authenticated participant only. Both DM participants must be active; administrator role supplies no exception.
```

- [x] **Step 4: Run handler and contract checks**

Run: `go test ./internal/chat/send_direct_message/api` and `scripts/verify-contracts.ps1`.

Expected: PASS; the contract requires the DM send endpoint.

### Task 3: Document scope and run native validation

**Status:** Complete — full Go, contract, traceability, and whitespace checks pass.

**Files:**
- Modify: `TODO.md`

- [x] **Step 1: State the post-ban and ACL boundary in TODO**

```md
New messages require current membership and two unblocked participants in one SQL statement. The existing-history read path, reply, edit/delete, event, counter, attachment, notification, and search ACLs remain separate leaves.
```

- [x] **Step 2: Format and run native checks**

Run: `gofmt -w` for changed Go files, `go test ./...`, `go vet ./...`, `go build -o "$env:TEMP\voice-platform-api-dm-send-check.exe" ./cmd/api`, `scripts/verify-contracts.ps1`, `scripts/verify-spec-traceability.ps1`, and `git diff --check`.

Expected: all checks pass without creating an API binary in the workspace.

## Self-review

Coverage: the migration defines a conversation-scoped idempotency key; the insert query validates the actor is one of exactly two participants and both remain unblocked; session authentication supplies actor identity without a role predicate. This leaf neither lists nor reads messages, so administrator status cannot gain DM content access through it.

Type consistency: the route path uses `directMessageID`, JSON uses `client_message_id` and `body`, and the service uses `DirectMessageID`, `ClientMessageID`, and `Body` to build a single insert request.
