# Project Text Message Attachments Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Include only safe attached-file metadata in text-channel history so a later frontend leaf can construct the same-origin protected download action.

**Architecture:** The history query aggregates `ATTACHED` rows linked to each non-deleted text message in stored attachment position order, returning only attachment UUID, original name and measured byte size. The existing download endpoint remains the ACL and bytes authority: this projection carries neither a URL nor `storage_key`, and deleted messages always emit an empty attachment list.

**Tech Stack:** Go, PostgreSQL JSON aggregation, `encoding/json`, HTTP JSON API, OpenAPI.

---

### Task 1: Extend the history domain result without a storage capability

**Files:**
- Modify: `backend/internal/chat/list_text_messages/service.go`
- Modify: `backend/internal/chat/list_text_messages/service_test.go`

- [x] **Step 1: Add the failing preservation test.**

```go
store := &fakeStore{messages: []Message{{ID: "message-1", Attachments: []Attachment{{ID: attachmentID, OriginalName: "notes.svg", SizeBytes: 10}}}}}
result, err := New(store).List(context.Background(), Input{ChannelID: channelID, Limit: 1})
if err != nil || result.Messages[0].Attachments[0].OriginalName != "notes.svg" { t.Fatal("history metadata must survive pagination") }
```

- [x] **Step 2: Run the focused domain test before implementation.**

Run: `go test ./internal/chat/list_text_messages`

Expected: FAIL because `Attachment` and `Message.Attachments` are absent.

- [x] **Step 3: Define the safe projection type.**

```go
type Attachment struct { ID, OriginalName string; SizeBytes int64 }
type Message struct { /* existing fields */; Attachments []Attachment }
```

Do not add `storage_key`, media type, local path, inline URL or file contents. Preserve the existing newest-first cursor behavior.

- [x] **Step 4: Re-run the focused domain test.**

Run: `go test ./internal/chat/list_text_messages`

Expected: PASS.

### Task 2: Aggregate only live attached metadata in PostgreSQL

**Files:**
- Create: `backend/internal/chat/list_text_messages/postgres/attachments.go`
- Modify: `backend/internal/chat/list_text_messages/postgres/repository.go`
- Modify: `backend/internal/chat/list_text_messages/postgres/repository_test.go`

- [x] **Step 1: Extend the repository test with a JSON attachment array and SQL guards.**

```go
attachments := []byte(`[{"id":"` + attachmentID + `","original_name":"notes.svg","byte_size":10}]`)
for _, fragment := range []string{"attachments.state = 'ATTACHED'", "message_attachments.position", "messages.deleted_at IS NULL", "COALESCE("} {
    if !strings.Contains(database.statement, fragment) { t.Fatal(fragment) }
}
if result[0].Attachments[0].ID != attachmentID { t.Fatal("must decode only safe metadata") }
```

The existing deleted-message fixture must assert its attachment slice is empty.

- [x] **Step 2: Change the query to aggregate safe ordered JSON metadata.**

```sql
COALESCE(
  jsonb_agg(jsonb_build_object('id', attachments.id::text, 'original_name', attachments.original_name, 'byte_size', attachments.byte_size)
            ORDER BY message_attachments.position)
  FILTER (WHERE attachments.id IS NOT NULL AND messages.deleted_at IS NULL),
  '[]'::jsonb
) AS attachments
```

Join `message_attachments` and `attachments` with `attachments.state = 'ATTACHED'`, group by the existing message fields, and keep the cursor and message ordering semantics unchanged.

- [x] **Step 3: Decode and validate JSON in a focused helper.**

```go
func decodeAttachments(source []byte) ([]listtextmessages.Attachment, error) {
    var values []listtextmessages.Attachment
    if err := json.Unmarshal(source, &values); err != nil { return nil, err }
    for _, value := range values { if !validUUID(value.ID) || value.OriginalName == "" || value.SizeBytes < 0 || value.SizeBytes > 25_000_000 { return nil, ErrInvalidAttachmentProjection } }
    return values, nil
}
```

Reject malformed database projections rather than serializing a partial list; the helper must never parse or expose a storage key.

- [x] **Step 4: Re-run the repository package tests.**

Run: `go test ./internal/chat/list_text_messages/postgres`

Expected: PASS.

### Task 3: Serialize the metadata contract and document the boundary

**Files:**
- Modify: `backend/internal/chat/list_text_messages/api/http_handler.go`
- Modify: `backend/internal/chat/list_text_messages/api/http_handler_test.go`
- Modify: `contracts/openapi.yaml`
- Modify: `docs/API_AND_REALTIME.md`
- Modify: `docs/ARCHITECTURE_AND_DATA.md`
- Modify: `TODO.md`

- [x] **Step 1: Add a handler test that includes metadata but no capability.**

```go
message := listtextmessages.Message{ID: "message-1", Attachments: []listtextmessages.Attachment{{ID: attachmentID, OriginalName: "notes.svg", SizeBytes: 10}}}
if !strings.Contains(body, `"attachments":[{"id":"`+attachmentID) || strings.Contains(body, "storage_key") { t.Fatal("must project safe metadata only") }
```

- [x] **Step 2: Add an API-only attachment DTO.**

```go
type attachment struct { ID string `json:"id"`; OriginalName string `json:"original_name"`; SizeBytes int64 `json:"byte_size"` }
type message struct { /* existing fields */; Attachments []attachment `json:"attachments"` }
```

Always encode `attachments` as an array. A deleted message encodes `[]` even if an old link remains in the database.

- [x] **Step 3: Extend `TextMessageHistoryItem` in OpenAPI and state the download boundary.**

Add a required `attachments` array with `TextMessageAttachment` entries (`id`, `original_name`, `byte_size`). Document that clients must use the protected same-origin GET action; metadata does not prove authorization and does not contain a public URL.

- [x] **Step 4: Run native validation and inspect only the selected scope.**

Run: `go test ./...`; `go vet ./...`; `powershell -ExecutionPolicy Bypass -File scripts/verify-contracts.ps1`; `powershell -ExecutionPolicy Bypass -File scripts/verify-spec-traceability.ps1`; `git diff --check`.

Expected: all pass. Do not stage, deploy, or claim browser-visible attachment UX: composing attachments and rendering safe download controls are separate leaves.

**Coverage review:** This leaf closes the safe text-history metadata gap for T-044/T-045. It does not add an upload picker, a download button, image preview, file MIME processing, DM attachment metadata, a public URL, attachment-content search, physical collection or an authenticated end-to-end download evidence run.
