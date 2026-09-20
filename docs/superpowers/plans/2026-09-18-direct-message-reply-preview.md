# Direct-message Reply Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Return a safe, same-DM reply preview with each direct-message history item, including a deletion marker state instead of deleted text.

**Architecture:** Extend only the existing `list_direct_message_history` projection. Its existing participant-only `readable_pair` CTE remains the authorization boundary; a same-conversation `LEFT JOIN` may load a referenced message only after the history row is authorized. The preview exposes ID, author ID, body and deleted state; a deleted reply has an empty body and `deleted:true`, so the client can render «Сообщение удалено» without receiving retained text.

**Tech Stack:** Go 1.26, PostgreSQL/pgx, net/http, OpenAPI 3.1, Go testing.

---

### Task 1: Write failing reply-preview projection tests

**Files:**
- Modify: `backend/internal/chat/list_direct_message_history/postgres/repository_test.go`
- Modify: `backend/internal/chat/list_direct_message_history/api/http_handler_test.go`

- [x] **Step 1: Make the repository test expect a visible preview and its safe deletion state**

```go
values: [][]any{{
    messageID, directMessageID, actorID, clientMessageID, "answer", replyID,
    createdAt, nil, 1, false, replyID, otherID, "", true,
}}
if result[0].ReplyPreview == nil || result[0].ReplyPreview.ID != replyID ||
    result[0].ReplyPreview.Body != "" || !result[0].ReplyPreview.Deleted {
    t.Fatalf("result=%#v", result)
}
```

The SQL assertion must require `LEFT JOIN direct_message_messages reply`,
`reply.direct_message_id = m.direct_message_id`, and a `CASE` that clears a
deleted reply body. It must reject `blocked_at` and any role string.

- [x] **Step 2: Make the HTTP response test expect the nested preview**

```go
Messages: []listdirectmessagehistory.Message{{
    ID: messageID,
    ReplyToID: replyID,
    ReplyPreview: &listdirectmessagehistory.ReplyPreview{
        ID: replyID, AuthorID: otherID, Body: "", Deleted: true,
    },
}}
if !strings.Contains(recorder.Body.String(), `"reply_preview":{"id":"`+replyID+`"`) ||
    !strings.Contains(recorder.Body.String(), `"deleted":true`) {
    t.Fatalf("body=%q", recorder.Body.String())
}
```

- [x] **Step 3: Run focused tests to prove the missing model and projection fail**

Run: `go test ./internal/chat/list_direct_message_history/...`

Expected: FAIL because `ReplyPreview` is not defined and the SQL does not return preview columns.

### Task 2: Add the participant-scoped same-DM projection

**Files:**
- Modify: `backend/internal/chat/list_direct_message_history/service.go`
- Modify: `backend/internal/chat/list_direct_message_history/postgres/repository.go`

- [x] **Step 1: Add the nullable reply-preview model to one history item**

```go
type ReplyPreview struct {
    ID, AuthorID, Body string
    Deleted            bool
}
type Message struct {
    // existing fields
    ReplyPreview *ReplyPreview
}
```

`nil` means the message has no `reply_to_id`; an empty body plus `Deleted:true`
means the referenced original is retained but soft-deleted.

- [x] **Step 2: Join only the reply in the already-readable DM and redact deleted body**

```sql
LEFT JOIN direct_message_messages reply
  ON reply.id = m.reply_to_id
 AND reply.direct_message_id = m.direct_message_id
```

```sql
COALESCE(reply.id::text, ''), COALESCE(reply.author_id::text, ''),
CASE WHEN reply.deleted_at IS NULL THEN COALESCE(reply.body, '') ELSE '' END,
COALESCE(reply.deleted_at IS NOT NULL, false)
```

Scan these fields into a temporary value and assign `message.ReplyPreview`
only when the returned reply ID is non-empty. Do not add a second ACL query,
role parameter, admin exception, `blocked_at` predicate, physical delete, or
cross-conversation lookup.

- [x] **Step 3: Run focused tests to verify the projection passes**

Run: `go test ./internal/chat/list_direct_message_history/...`

Expected: PASS; history remains participant-only after a block, previews cannot
cross the DM boundary, and a deleted original exposes no old body.

### Task 3: Publish the response contract and update traceability

**Files:**
- Modify: `backend/internal/chat/list_direct_message_history/api/http_handler.go`
- Modify: `contracts/openapi.yaml`
- Modify: `scripts/verify-contracts.ps1`
- Modify: `TODO.md`

- [x] **Step 1: Serialize the optional safe nested preview**

```go
type replyPreview struct {
    ID      string `json:"id"`
    AuthorID string `json:"author_id"`
    Body    string `json:"body"`
    Deleted bool   `json:"deleted"`
}
type message struct {
    // existing fields
    ReplyPreview *replyPreview `json:"reply_preview,omitempty"`
}
```

Map it from `Message.ReplyPreview`; no preview appears for a non-reply.

- [x] **Step 2: Define `DirectMessageReplyPreview` and reference it from history**

```json
"reply_preview": { "$ref": "#/components/schemas/DirectMessageReplyPreview" }
```

The schema requires `id`, `author_id`, `body`, and `deleted`. Its description
states that only the same participant-authorized history projection returns it
and that deleted messages always have an empty body.

- [x] **Step 3: Add a contract verifier assertion and amend T-041 status**

```powershell
if ($null -eq $openApi.components.schemas.DirectMessageMessageHistoryItem.properties.reply_preview) {
    throw 'DM history contract must define reply_preview.'
}
```

Replace the TODO statement that history has no reply preview with the precise
same-DM, deleted-body-redaction guarantee. Events, counters, notifications,
attachments and search remain separate leaves.

- [x] **Step 4: Run native validation**

Run: `gofmt -w` for changed Go files, `go test ./...`, `go vet ./...`,
`go build -o "$env:TEMP\voice-platform-api-dm-reply-preview-check.exe" ./cmd/api`,
`scripts/verify-contracts.ps1`, `scripts/verify-spec-traceability.ps1`, and
`git diff --check`.

Expected: all checks pass. This verifies code and contracts only; it is not a
real PostgreSQL integration test, a WebSocket event implementation or media evidence.

## Self-review

Coverage: this plan implements the reply-preview portion of `REQ-DM-01` and
the deletion non-leak requirement from `REQ-CHAT-01`, preserving
`REQ-SECURITY-02` through the existing participant CTE plus same-DM join.
It deliberately leaves events, counters, notifications, attachments and search
as independent capabilities.

Placeholder scan: no placeholders. `ReplyPreview` names, SQL columns, JSON
object and OpenAPI schema use the same fields throughout.
