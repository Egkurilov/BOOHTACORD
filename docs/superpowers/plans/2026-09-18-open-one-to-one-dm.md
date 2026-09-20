# Open One-to-One DM Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create or reopen the single direct-message conversation between two distinct active accounts without an administrator bypass.

**Architecture:** Store an unordered pair as a canonical ascending UUID pair with a unique constraint. The application service validates two distinct UUIDs, generates an ID only for the upsert attempt, and maps a missing or blocked participant to one non-disclosing unavailable result. The authenticated HTTP route accepts only a participant ID; role never affects the store predicate.

**Tech Stack:** Go 1.26, PostgreSQL/pgx, net/http, embedded SQL migrations, OpenAPI 3.1, Go testing.

---

### Task 1: Persist a canonical active-account pair

**Status:** Complete — migration, service, and repository tests pass.

**Files:**
- Create: `backend/internal/database/migrate/migrations/0017_create_direct_messages.sql`
- Modify: `backend/internal/database/migrate/run_test.go`
- Create: `backend/internal/chat/open_direct_message/service.go`
- Create: `backend/internal/chat/open_direct_message/id.go`
- Create: `backend/internal/chat/open_direct_message/service_test.go`
- Create: `backend/internal/chat/open_direct_message/postgres/repository.go`
- Create: `backend/internal/chat/open_direct_message/postgres/repository_test.go`

- [x] **Step 1: Write failing service, repository, and migration tests**

```go
_, err := service.Open(context.Background(), Input{ActorID: actorID, ParticipantID: actorID})
if !errors.Is(err, ErrInvalidInput) || store.called { t.Fatalf("self DM was persisted") }
if !strings.Contains(transaction.statement, "blocked_at IS NULL") || !strings.Contains(transaction.statement, "ON CONFLICT (participant_one_id, participant_two_id)") {
  t.Fatalf("statement = %s", transaction.statement)
}
```

- [x] **Step 2: Run the new focused Go tests to verify failure**

Run: `go test ./internal/chat/open_direct_message/... ./internal/database/migrate`

Expected: FAIL because the `open_direct_message` leaf and migration do not exist.

- [x] **Step 3: Create the migration and canonical upsert leaf**

```sql
CREATE TABLE IF NOT EXISTS direct_messages (
    id UUID PRIMARY KEY,
    participant_one_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    participant_two_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT direct_messages_distinct_participants CHECK (participant_one_id < participant_two_id),
    CONSTRAINT direct_messages_unique_pair UNIQUE (participant_one_id, participant_two_id)
);
```

```go
const openDirectMessage = `
WITH active_pair AS (
    SELECT LEAST($1::uuid, $2::uuid) AS participant_one_id, GREATEST($1::uuid, $2::uuid) AS participant_two_id
    WHERE $1::uuid <> $2::uuid
      AND (SELECT count(*) FROM users WHERE id = ANY(ARRAY[$1::uuid, $2::uuid]) AND blocked_at IS NULL) = 2
), opened AS (
    INSERT INTO direct_messages (id, participant_one_id, participant_two_id)
    SELECT $3::uuid, participant_one_id, participant_two_id FROM active_pair
    ON CONFLICT (participant_one_id, participant_two_id) DO UPDATE SET participant_one_id = EXCLUDED.participant_one_id
    RETURNING id::text, participant_one_id::text, participant_two_id::text, created_at
)
SELECT * FROM opened`
```

- [x] **Step 4: Run focused Go tests to verify pass**

Run: `go test ./internal/chat/open_direct_message/... ./internal/database/migrate`

Expected: PASS with self-pair rejection, active-user predicate, concurrent-safe unique pair, and embedded migration coverage.

### Task 2: Expose the authenticated route without a role exception

**Status:** Complete — handler and contract checks pass.

**Files:**
- Create: `backend/internal/chat/open_direct_message/api/http_handler.go`
- Create: `backend/internal/chat/open_direct_message/api/http_handler_test.go`
- Modify: `backend/cmd/api/chat_routes.go`
- Modify: `contracts/openapi.yaml`
- Modify: `scripts/verify-contracts.ps1`

- [x] **Step 1: Write a failing handler test**

```go
request := httptest.NewRequest(http.MethodPost, "/api/v1/direct-messages", strings.NewReader(`{"participant_id":"22222222-2222-4222-8222-222222222222"}`))
request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "11111111-1111-4111-8111-111111111111", Role: "ADMINISTRATOR"}))
handler.ServeHTTP(recorder, request)
if recorder.Code != http.StatusCreated || input.ActorID == "" || input.ParticipantID == "" { t.Fatalf("status=%d input=%#v", recorder.Code, input) }
```

- [x] **Step 2: Run the handler test to verify failure**

Run: `go test ./internal/chat/open_direct_message/api`

Expected: FAIL because the handler and route binding do not exist.

- [x] **Step 3: Implement the handler, binding, and contract**

```go
mux.Handle("POST /api/v1/direct-messages", sessionapi.Require(sessions)(directmessageapi.NewHandler(directMessageService)))
```

```yaml
"/api/v1/direct-messages":
  post:
    operationId: openDirectMessage
    description: Authenticated account only. Opens the unique DM pair when both accounts are active; administrator status never grants access to another pair.
```

- [x] **Step 4: Run the focused handler and contract checks**

Run: `go test ./internal/chat/open_direct_message/api` and `scripts/verify-contracts.ps1`.

Expected: PASS; the contract requires `POST /api/v1/direct-messages`.

### Task 3: Record implemented scope and run native validation

**Status:** Complete — full Go, contract, traceability, and whitespace checks pass.

**Files:**
- Modify: `TODO.md`

- [x] **Step 1: State exactly what this leaf proves**

```md
The pair is canonical and unique under concurrent creation. Only two active accounts can open it; administrator status has no ACL exception. DM history, messages, search, attachments, counters, events, and post-ban send prevention remain separate leaves.
```

- [x] **Step 2: Format and run the native checks**

Run: `gofmt -w` for changed Go files, `go test ./...`, `go vet ./...`, `go build -o "$env:TEMP\voice-platform-api-dm-check.exe" ./cmd/api`, `scripts/verify-contracts.ps1`, `scripts/verify-spec-traceability.ps1`, and `git diff --check`.

Expected: all tests, vet, build, contract, traceability, and whitespace checks pass.

## Self-review

Coverage: the database constraint and upsert ensure one conversation per pair; the query rejects either blocked account; session authentication supplies the caller; no administrator predicate occurs in the service, SQL, or handler. This leaf deliberately does not expose conversation history or message content, so it cannot create a DM-read bypass.

Type consistency: `Input` supplies `ActorID` and `ParticipantID`; `Result` returns the canonical participant IDs and conversation ID; the OpenAPI request uses `participant_id` and maps directly to `ParticipantID`.
