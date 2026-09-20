# Attachment Staged Upload Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a private storage leaf that streams one untrusted upload to a random temporary file and enforces the inclusive 25,000,000-byte limit.

**Architecture:** `write_upload` owns only trusted temporary-path creation, byte counting, fsync and cleanup. It neither exposes HTTP paths nor decides conversation ACL, attachment metadata, disk-space reservations or message linking; those become dependent leaves after the staged writer has a stable result contract.

**Tech Stack:** Go standard library (`io`, `os`, `context`), Go unit tests.

---

### Task 1: Specify rejected and successful stream outcomes

**Files:**
- Create: `backend/internal/storage/write_upload/service_test.go`
- Create: `backend/internal/storage/write_upload/service.go`

- [x] **Step 1: Write failing tests for the exact byte boundary and cleanup.**

```go
writer, err := New(t.TempDir())
result, err := writer.Write(context.Background(), repeatedReader{remaining: MaxBytes})
if err != nil || result.SizeBytes != MaxBytes { t.Fatal("limit must be inclusive") }

_, err = writer.Write(context.Background(), repeatedReader{remaining: MaxBytes + 1})
if !errors.Is(err, ErrTooLarge) { t.Fatal("oversized stream must be rejected") }
```

Also assert that a source read failure removes every `.part` file and a cancelled context creates no file.

- [x] **Step 2: Run the focused package before implementation.**

Run: `go test ./internal/storage/write_upload`

Expected: FAIL because the `write_upload` package does not exist.

- [x] **Step 3: Implement the isolated writer.**

```go
const MaxBytes int64 = 25_000_000

type Result struct { TempPath string; SizeBytes int64 }

func (writer Writer) Write(ctx context.Context, source io.Reader) (Result, error) {
    if err := ctx.Err(); err != nil { return Result{}, err }
    file, err := os.CreateTemp(writer.directory, "upload-*.part")
    // Remove the temporary path on every failure.
    // Copy at most MaxBytes+1, reject the extra byte, then Sync and Close.
}
```

`New` rejects an empty or non-directory trusted root. The API layer must never return `TempPath` to a browser or log it.

- [x] **Step 4: Run the focused package and the backend suite.**

Run: `go test ./internal/storage/write_upload`; then `go test ./...`

Expected: PASS. The test suite has no public URL, metadata or ACL assertions because this leaf deliberately has none.

### Task 2: Record the contract boundary

**Files:**
- Modify: `docs/ARCHITECTURE_AND_DATA.md`

- [x] **Step 1: Amend the attachment state-machine note.**

State that the staged writer accepts at most 25,000,000 bytes into a `0600` random `.part` file and removes it on read, write, limit or context failure; it is not an attachment row and cannot be downloaded or attached yet.

- [x] **Step 2: Validate requirements traceability.**

Run: `powershell -File scripts/verify-spec-traceability.ps1`

Expected: PASS with the existing requirement mapping intact.

## Self-review

- The leaf enforces measured bytes rather than `Content-Length` and does not load the upload into memory.
- The result remains private to later storage code; it has no HTTP endpoint, no random URL and no public bucket.
- Space reservation, target-conversation ACL, attachment metadata, atomic final move, download authorization and retention cleanup are intentionally outside this leaf and remain unchecked in T-044 through T-047.
