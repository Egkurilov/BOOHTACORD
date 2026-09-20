# Download Text Attachment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let an authenticated active account download one attached, non-deleted text-channel attachment only when it still has access to the current channel.

**Architecture:** `download_text_attachment` authorizes and fetches metadata through one PostgreSQL query before it opens a private file. The query requires an active actor, an unarchived `TEXT` channel, an attached object linked to a non-deleted message in that same channel. The HTTP boundary always forces a safe attachment download and never returns a storage key, inline content type, direct path, or public URL.

**Tech Stack:** Go, pgx, `net/http`, private local filesystem, focused Go tests, OpenAPI.

---

### Task 1: Define an ACL-first private-file read command

**Files:**
- Create: `backend/internal/storage/download_text_attachment/service.go`
- Create: `backend/internal/storage/download_text_attachment/service_test.go`
- Create: `backend/internal/storage/download_text_attachment/files.go`
- Create: `backend/internal/storage/download_text_attachment/files_test.go`

- [x] **Step 1: Write focused service tests before the command exists.**

```go
opened, err := New(store, files).Open(context.Background(), Input{ActorID: actorID, ChannelID: channelID, AttachmentID: attachmentID})
if err != nil || opened.OriginalName != "game-log.svg" || files.key != storageKey { t.Fatal("must open only authorized metadata") }

_, err = New(&fakeStore{err: ErrAttachmentUnavailable}, files).Open(context.Background(), Input{ActorID: actorID, ChannelID: channelID, AttachmentID: attachmentID})
if !errors.Is(err, ErrAttachmentUnavailable) || files.called { t.Fatal("unavailable object must never touch storage") }
```

- [x] **Step 2: Run the focused service test and confirm it fails because the package is absent.**

Run: `go test ./internal/storage/download_text_attachment`

Expected: FAIL before implementation.

- [x] **Step 3: Implement UUID validation, metadata lookup and bounded unavailable mapping.**

```go
type Input struct{ ActorID, ChannelID, AttachmentID string }
type Metadata struct{ OriginalName, StorageKey string; SizeBytes int64 }
type Store interface { Find(context.Context, Input) (Metadata, error) }
type Files interface { Open(string, int64) (io.ReadCloser, error) }

func (service Service) Open(ctx context.Context, input Input) (Opened, error) {
    if !validInput(input) { return Opened{}, ErrInvalidInput }
    metadata, err := service.store.Find(ctx, input)
    if errors.Is(err, ErrAttachmentUnavailable) { return Opened{}, ErrAttachmentUnavailable }
    if err != nil { return Opened{}, fmt.Errorf("find downloadable attachment: %w", err) }
    reader, err := service.files.Open(metadata.StorageKey, metadata.SizeBytes)
    if err != nil { return Opened{}, fmt.Errorf("open authorized attachment: %w", err) }
    return Opened{Metadata: metadata, Reader: reader}, nil
}
```

Validate all three UUIDs and require a non-empty UTF-8 name, canonical UUID storage key and `0 <= SizeBytes <= 25_000_000`. Do not log any filename, key or file bytes.

- [x] **Step 4: Implement private file opening with a regular-file and exact-size check.**

```go
func (store FileStore) Open(key string, expectedSize int64) (io.ReadCloser, error) {
    path, err := store.storagePath(key)
    if err != nil { return nil, err }
    info, err := os.Lstat(path)
    if err != nil || !info.Mode().IsRegular() || info.Size() != expectedSize { return nil, ErrFileUnavailable }
    return os.Open(path)
}
```

Resolve the configured private directory once in `NewFileStore`; construct the leaf path only from a canonical UUID; reject a missing, non-regular or mismatched-size object. This command never lists directories and never accepts an arbitrary path.

- [x] **Step 5: Re-run the package tests.**

Run: `go test ./internal/storage/download_text_attachment`

Expected: PASS, including invalid ID, unavailable metadata, no-open-before-ACL, missing/private-file and size-mismatch cases.

### Task 2: Make one PostgreSQL predicate authorize the download

**Files:**
- Create: `backend/internal/storage/download_text_attachment/postgres/repository.go`
- Create: `backend/internal/storage/download_text_attachment/postgres/pool_database.go`
- Create: `backend/internal/storage/download_text_attachment/postgres/repository_test.go`

- [x] **Step 1: Write the query-shape and zero-row tests.**

```go
for _, fragment := range []string{
    "users.blocked_at IS NULL", "channels.kind = 'TEXT'", "channels.archived_at IS NULL",
    "attachments.state = 'ATTACHED'", "messages.deleted_at IS NULL",
    "message_attachments.attachment_id = attachments.id", "attachments.channel_id = channels.id",
} { if !strings.Contains(database.statement, fragment) { t.Fatal(fragment) } }
```

Assert exactly three parameter values (actor, channel, attachment) and that `pgx.ErrNoRows` is `downloadtextattachment.ErrAttachmentUnavailable`.

- [x] **Step 2: Implement the parameterized metadata query.**

```sql
SELECT attachments.original_name, attachments.storage_key::text, attachments.byte_size
FROM users
JOIN channels ON channels.id = $2
JOIN attachments ON attachments.id = $3 AND attachments.channel_id = channels.id
JOIN message_attachments ON message_attachments.attachment_id = attachments.id
JOIN messages ON messages.id = message_attachments.message_id AND messages.channel_id = channels.id
WHERE users.id = $1
  AND users.blocked_at IS NULL
  AND channels.kind = 'TEXT'
  AND channels.archived_at IS NULL
  AND attachments.state = 'ATTACHED'
  AND messages.deleted_at IS NULL
```

No role parameter or unbounded attachment path is permitted. A deleted message, detached object, wrong channel, blocked actor, archived/voice channel or absent object has the same unavailable outcome.

- [x] **Step 3: Run focused command and repository tests.**

Run: `go test ./internal/storage/download_text_attachment/...`

Expected: PASS.

### Task 3: Expose a safe authenticated download route and contract

**Files:**
- Create: `backend/internal/storage/download_text_attachment/api/http_handler.go`
- Create: `backend/internal/storage/download_text_attachment/api/http_handler_test.go`
- Modify: `backend/cmd/api/storage_routes.go`
- Modify: `contracts/openapi.yaml`
- Modify: `docs/ARCHITECTURE_AND_DATA.md`

- [x] **Step 1: Write handler tests for a forced download and indistinguishable unavailable result.**

```go
if recorder.Code != http.StatusOK || recorder.Header().Get("Content-Type") != "application/octet-stream" ||
   !strings.HasPrefix(recorder.Header().Get("Content-Disposition"), "attachment;") ||
   recorder.Header().Get("X-Content-Type-Options") != "nosniff" || recorder.Body.String() != "safe bytes" {
    t.Fatal("must serve only safe attachment bytes")
}
```

Also assert a service `ErrAttachmentUnavailable` returns `404 NOT_FOUND` without a storage key or filename, and that a malformed identifier returns `400 VALIDATION_FAILED`.

- [x] **Step 2: Implement the handler and route wiring.**

```go
mux.Handle("GET /api/v1/channels/{channelID}/attachments/{attachmentID}",
    sessionapi.Require(sessions)(downloadapi.NewHandler(downloader)))
```

The handler derives `ActorID` solely from `sessionapi.PrincipalFrom`, opens once, defers the reader close, sets `Content-Type: application/octet-stream`, `Content-Disposition` via `mime.FormatMediaType("attachment", map[string]string{"filename": name})`, `X-Content-Type-Options: nosniff`, and the verified `Content-Length`, then copies bytes. It returns a bounded Russian error response and never logs or serializes private metadata.

- [x] **Step 3: Extend the documented API without a public URL.**

Add `GET /api/v1/channels/{channelID}/attachments/{attachmentID}` with `200` binary attachment, `400`, `401`, `404`, and `500` responses. State that it is not an image preview endpoint and performs the current ACL check before each file read. Update the architecture text to record the same predicate and safe headers.

- [x] **Step 4: Run native validation and inspect scope.**

Run: `go test ./...`; `go vet ./...`; `powershell -ExecutionPolicy Bypass -File scripts/verify-contracts.ps1`; `powershell -ExecutionPolicy Bypass -File scripts/verify-spec-traceability.ps1`; `git diff --check`.

Expected: all pass. Inspect only this leaf's file sizes and `git status --short`; do not stage, commit, deploy or claim a real attachment download was proven without an authenticated integration run.

**Coverage review:** This leaf satisfies the text-channel portion of T-045: every download is re-authorized, a deleted message hides its linked file, storage remains private, and active formats are forced to download. It deliberately does not add DM attachments, raster previews, attachment display in message history, physical garbage collection, direct-message access, or a real PostgreSQL/browser evidence run.
