# Direct-message Unread Count Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Include each caller's unread direct-message count in their already participant-scoped DM navigation list.

**Architecture:** Extend only `list_direct_messages`. The existing `pair` CTE remains the sole source of readable DM IDs; a left join can see only the caller's own cursor and messages in that pair. `unread_count` is the number of messages authored by the other participant with `(created_at, id)` strictly after the caller's effective cursor; no cursor means all other-author messages are unread. No message body, raw activity time, role or blocked-account condition is exposed.

**Tech Stack:** Go 1.26, PostgreSQL/pgx, net/http, OpenAPI 3.1, Go testing.

---

### Task 1: Write failing unread-count projection tests

**Files:**
- Modify: `backend/internal/chat/list_direct_messages/postgres/repository_test.go`
- Modify: `backend/internal/chat/list_direct_messages/api/http_handler_test.go`

- [x] **Step 1: Expect a per-caller unread count from the repository**

```go
database := &fakeDatabase{rows: &fakeRows{values: [][]any{{dmID, otherID, "Собеседник", time.Unix(1, 0), int64(3)}}}}
result, err := New(database).List(ctx, listdirectmessages.Request{Input: listdirectmessages.Input{ActorID: actorID}})
if err != nil || result[0].UnreadCount != 3 { t.Fatalf("result=%#v error=%v", result, err) }
```

Require the query to join `direct_message_read_cursors cursor` only on
`cursor.account_id = $1` plus the pair ID, count only
`message.author_id <> $1::uuid`, and compare `(message.created_at, message.id)`
against the cursor tuple. Reject `blocked_at`, `ADMINISTRATOR`, `message.body`
and `message.edited_at` so the navigation count cannot become a content or
role-based side channel.

- [x] **Step 2: Expect `unread_count` in the authenticated HTTP response**

```go
return listdirectmessages.Result{DirectMessages: []listdirectmessages.DirectMessage{{ID: dmID, UnreadCount: 3}}}, nil
if !strings.Contains(recorder.Body.String(), `"unread_count":3`) { t.Fatalf("body=%q", recorder.Body.String()) }
```

- [x] **Step 3: Run focused tests to prove the missing field fails**

Run: `go test ./internal/chat/list_direct_messages/...`

Expected: FAIL because `UnreadCount` is not part of the projection or response.

### Task 2: Project only the caller's unread messages

**Files:**
- Modify: `backend/internal/chat/list_direct_messages/service.go`
- Modify: `backend/internal/chat/list_direct_messages/postgres/repository.go`

- [x] **Step 1: Add an `int64` unread count to the navigation item**

```go
type DirectMessage struct {
    ID, OtherParticipantID, OtherParticipantDisplayName string
    CreatedAt                                           time.Time
    UnreadCount                                         int64
}
```

- [x] **Step 2: Count other-author messages after the caller's own cursor**

```sql
LEFT JOIN direct_message_read_cursors cursor
  ON cursor.account_id = $1::uuid
 AND cursor.direct_message_id = pair.id
LEFT JOIN direct_message_messages message
  ON message.direct_message_id = pair.id
SELECT ..., COUNT(message.id) FILTER (
    WHERE message.author_id <> $1::uuid
      AND (cursor.message_id IS NULL OR (message.created_at, message.id) > (cursor.message_created_at, cursor.message_id))
) AS unread_count
```

Group by only the pair navigation fields. Do not filter either participant by
`blocked_at`: retained DM history remains navigable after a block. Do not return
message bodies, timestamps of the newest unseen message, author role or other
participant read state.

- [x] **Step 3: Run focused tests to verify the projection passes**

Run: `go test ./internal/chat/list_direct_messages/...`

Expected: PASS with a caller-specific count and no role/content leakage.

### Task 3: Publish the navigation contract and T-042 boundary

**Files:**
- Modify: `backend/internal/chat/list_direct_messages/api/http_handler.go`
- Modify: `contracts/openapi.yaml`
- Modify: `scripts/verify-contracts.ps1`
- Modify: `docs/API_AND_REALTIME.md`
- Modify: `TODO.md`

- [x] **Step 1: Serialize only `unread_count`**

```go
type directMessage struct {
    // existing public navigation fields
    UnreadCount int64 `json:"unread_count"`
}
```

The handler still derives only `ActorID` from the session principal and does
not receive its role.

- [x] **Step 2: Require the count in `DirectMessageListItem`**

```json
"unread_count": { "type": "integer", "minimum": 0 }
```

Update the `GET /direct-messages` description to say this is caller-local and
computed from the participant's own monotonic cursor. Add a contract verifier
assertion for the property.

- [x] **Step 3: Document scope without claiming counters or visibility UI are complete**

Record that the count includes no other user's read state or message content,
and amend T-042 to distinguish implemented DM navigation count from remaining
text-channel counts, mention IDs, browser visibility gating and desktop
notifications.

- [x] **Step 4: Run native validation**

Run: `gofmt -w` for changed Go files, `go test ./...`, `go vet ./...`,
`go build -o "$env:TEMP\voice-platform-api-dm-unread-count-check.exe" ./cmd/api`,
`scripts/verify-contracts.ps1`, `scripts/verify-spec-traceability.ps1`, and
`git diff --check`.

Expected: all checks pass. This validates the static query and API contract,
not a real PostgreSQL count under concurrent cursor writes or frontend display.

## Self-review

Coverage: implements the DM navigation-count portion of `REQ-CHAT-02` while
preserving the participant-only rule in `REQ-DM-01` and `REQ-SECURITY-02`. It
does not add text-channel unread counts, mention persistence, realtime events,
desktop notifications, browser visibility enforcement or another user's state.

Placeholder scan: no placeholders. `UnreadCount`, the caller ID, cursor tuple
and navigation projection are consistently named across tests, Go, SQL and the
contract.
