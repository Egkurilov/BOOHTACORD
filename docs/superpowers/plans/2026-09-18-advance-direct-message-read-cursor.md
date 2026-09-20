# Direct-message Read Cursor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a direct-message participant advance only their own read cursor to a shown message in that same canonical DM, never backwards.

**Architecture:** Add a `direct_message_read_cursors` table keyed by `(account_id, direct_message_id)`. A dedicated `advance_direct_message_read_cursor` leaf validates path/body IDs and issues one SQL statement: it derives participant membership plus the selected in-DM message, performs an ordered upsert, and returns either the advanced or already newer cursor. Role and `blocked_at` never participate; retained history still lets either participant advance their own cursor after a block. The browser must call it only when a DM is active, visible, and its message is shown; the server does not claim it can infer browser visibility.

**Tech Stack:** Go 1.26, PostgreSQL/pgx, net/http, OpenAPI 3.1, Go testing.

---

### Task 1: Define the durable cursor invariant and failing leaf tests

**Files:**
- Create: `backend/internal/database/migrate/migrations/0021_create_direct_message_read_cursors.sql`
- Modify: `backend/internal/database/migrate/run_test.go`
- Create: `backend/internal/chat/advance_direct_message_read_cursor/service_test.go`
- Create: `backend/internal/chat/advance_direct_message_read_cursor/postgres/repository_test.go`
- Create: `backend/internal/chat/advance_direct_message_read_cursor/api/http_handler_test.go`

- [x] **Step 1: Create the migration with one cursor per participant and DM**

```sql
CREATE TABLE IF NOT EXISTS direct_message_read_cursors (
    account_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    direct_message_id UUID NOT NULL REFERENCES direct_messages(id) ON DELETE RESTRICT,
    message_id UUID NOT NULL REFERENCES direct_message_messages(id) ON DELETE RESTRICT,
    message_created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (account_id, direct_message_id)
);
```

`message_created_at` is copied only from the target message inside the guarded
command; clients never supply ordering data.

- [x] **Step 2: Write service and repository tests for ownership, monotonicity, and denial**

```go
result, err := New(store).Advance(ctx, Input{ActorID: actorID, DirectMessageID: dmID, MessageID: messageID})
if err != nil || result.MessageID != messageID || store.request.ActorID != actorID { t.Fatalf("result=%#v request=%#v error=%v", result, store.request, err) }
```

The repository test asserts `ON CONFLICT (account_id, direct_message_id)`,
the tuple comparison on `(message_created_at, message_id)`, the pair predicate
and `message.direct_message_id = dm.id`. It rejects `ADMINISTRATOR` and
`blocked_at`; `pgx.ErrNoRows` must normalize to `ErrDirectMessageUnavailable`.

- [x] **Step 3: Write the handler test with an Administrator principal**

```go
request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: actorID, Role: "ADMINISTRATOR"}))
handler.ServeHTTP(recorder, request)
if recorder.Code != http.StatusOK || input.ActorID != actorID || input.MessageID != messageID { t.Fatalf("status=%d input=%#v", recorder.Code, input) }
```

This proves a role is not accepted as a second authorization mechanism.

- [x] **Step 4: Run focused tests to verify they fail**

Run: `go test ./internal/chat/advance_direct_message_read_cursor/...`

Expected: FAIL because the capability, its result and HTTP adapter do not exist.

### Task 2: Implement the atomic monotonic advance

**Files:**
- Create: `backend/internal/chat/advance_direct_message_read_cursor/service.go`
- Create: `backend/internal/chat/advance_direct_message_read_cursor/postgres/repository.go`
- Create: `backend/internal/chat/advance_direct_message_read_cursor/postgres/pool_database.go`

- [x] **Step 1: Validate three UUIDs and preserve the nondisclosing unavailable result**

```go
type Input struct{ ActorID, DirectMessageID, MessageID string }
type Result struct { MessageID string; MessageCreatedAt time.Time }
func (service Service) Advance(ctx context.Context, input Input) (Result, error) {
    if !validUUID(input.ActorID) || !validUUID(input.DirectMessageID) || !validUUID(input.MessageID) { return Result{}, ErrInvalidInput }
    result, err := service.store.Advance(ctx, Request{Input: input})
    if errors.Is(err, ErrDirectMessageUnavailable) { return Result{}, ErrDirectMessageUnavailable }
    if err != nil { return Result{}, fmt.Errorf("advance direct message read cursor: %w", err) }
    return result, nil
}
```

- [x] **Step 2: Guard target membership and upsert only a newer cursor in one SQL statement**

```sql
WITH visible_message AS (
    SELECT message.id, message.created_at
    FROM direct_messages dm
    JOIN direct_message_messages message
      ON message.id = $3
     AND message.direct_message_id = dm.id
    WHERE dm.id = $2
      AND $1::uuid IN (dm.participant_one_id, dm.participant_two_id)
), upserted AS (
    INSERT INTO direct_message_read_cursors (account_id, direct_message_id, message_id, message_created_at)
    SELECT $1, $2, visible_message.id, visible_message.created_at FROM visible_message
    ON CONFLICT (account_id, direct_message_id) DO UPDATE
    SET message_id = CASE WHEN (direct_message_read_cursors.message_created_at, direct_message_read_cursors.message_id)
            < (EXCLUDED.message_created_at, EXCLUDED.message_id) THEN EXCLUDED.message_id ELSE direct_message_read_cursors.message_id END,
        message_created_at = CASE WHEN (direct_message_read_cursors.message_created_at, direct_message_read_cursors.message_id)
            < (EXCLUDED.message_created_at, EXCLUDED.message_id) THEN EXCLUDED.message_created_at ELSE direct_message_read_cursors.message_created_at END,
        updated_at = CASE WHEN (direct_message_read_cursors.message_created_at, direct_message_read_cursors.message_id)
            < (EXCLUDED.message_created_at, EXCLUDED.message_id) THEN now() ELSE direct_message_read_cursors.updated_at END
    RETURNING message_id::text, message_created_at
)
SELECT message_id, message_created_at FROM upserted
```

An old valid acknowledgement returns the existing newer cursor without relying
on a second statement-snapshot read. A foreign
participant, foreign message or missing pair returns zero rows and one generic
unavailable result. Do not add an admin exception or `blocked_at` filter.

- [x] **Step 3: Run focused tests to verify the leaf passes**

Run: `go test ./internal/chat/advance_direct_message_read_cursor/...`

Expected: PASS with atomic pair/message validation and monotonic cursor output.

### Task 3: Register the protected API and contract

**Files:**
- Create: `backend/internal/chat/advance_direct_message_read_cursor/api/http_handler.go`
- Modify: `backend/cmd/api/chat_routes.go`
- Modify: `contracts/openapi.yaml`
- Modify: `scripts/verify-contracts.ps1`
- Modify: `TODO.md`
- Modify: `docs/API_AND_REALTIME.md`

- [x] **Step 1: Decode only `message_id` and derive the actor from the session**

```go
var body struct { MessageID string `json:"message_id"` }
decoder := json.NewDecoder(http.MaxBytesReader(writer, request.Body, 8<<10))
decoder.DisallowUnknownFields()
if err := decoder.Decode(&body); err != nil { writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректный курсор личного диалога"); return }
result, err := advancer.Advance(request.Context(), advancedirectmessagereadcursor.Input{ActorID: principal.AccountID, DirectMessageID: request.PathValue("directMessageID"), MessageID: body.MessageID})
```

Return `200` with the effective current cursor. Map an unavailable pair or
message to generic `404`; the global origin middleware protects this `PUT`.

- [x] **Step 2: Construct and register the leaf without role input**

```go
directMessageReadCursor := advancedirectmessagereadcursor.New(advancedirectmessagereadcursorpostgres.New(advancedirectmessagereadcursorpostgres.NewPoolDatabase(database)))
mux.Handle("PUT /api/v1/direct-messages/{directMessageID}/read-cursor", sessionapi.Require(sessions)(advancedirectmessagereadcursorapi.NewHandler(directMessageReadCursor)))
```

- [x] **Step 3: Publish the explicit active-visible-message contract and API rule**

```json
"put": {
  "operationId": "advanceDirectMessageReadCursor",
  "description": "Authenticated participant only. The browser sends a message actually shown in its active visible DM; the server advances only that participant's cursor monotonically and grants no administrator exception."
}
```

Use `DirectMessageReadCursorRequest` (`message_id`) and
`DirectMessageReadCursor` (`direct_message_id`, `message_id`,
`message_created_at`). Add a verifier assertion and record that this implements
only the DM cursor part of T-042; UI visibility gating, counters and desktop
notifications remain separate leaves. Document the same client-side visibility
precondition in `docs/API_AND_REALTIME.md`, including the fact that a delayed
valid acknowledgement returns the already newer cursor.

- [x] **Step 4: Run native validation**

Run: `gofmt -w` for changed Go files, `go test ./...`, `go vet ./...`,
`go build -o "$env:TEMP\voice-platform-api-dm-read-cursor-check.exe" ./cmd/api`,
`scripts/verify-contracts.ps1`, `scripts/verify-spec-traceability.ps1`, and
`git diff --check`.

Expected: all checks pass. They validate code and contracts, not real PostgreSQL
transactions or user browser visibility.

## Self-review

Coverage: implements the private DM portion of monotonic read cursors in
`REQ-CHAT-02`, while maintaining the participant-only and post-block retained
history rules in `REQ-DM-01` and `REQ-SECURITY-02`. It does not falsely claim
that the browser has enforced active/visible UI state, nor implement unread
counters, mention parsing, realtime delivery or desktop notifications.

Placeholder scan: no placeholders. The same `ActorID`, `DirectMessageID`,
`MessageID`, `MessageCreatedAt` and unavailable outcome are defined in tests,
service, SQL, HTTP and contract steps.
