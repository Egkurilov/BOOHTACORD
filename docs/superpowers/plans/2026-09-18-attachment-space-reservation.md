# Attachment Space Reservation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Atomically reserve the full maximum attachment size before accepting one upload, preserving the larger of 2 GiB or 10% of the attachment filesystem for every concurrent request.

**Architecture:** `reserve_upload_space` receives filesystem snapshots through a small interface and maintains only in-process reservations behind one mutex. A caller receives a non-copyable reservation handle and must release it after the writer has either atomically moved or removed its temporary file; this leaf neither trusts `Content-Length` nor performs I/O or exposes an HTTP endpoint.

**Tech Stack:** Go standard library (`context`, `sync`), Go unit tests.

---

### Task 1: Prove admission is capacity-safe under concurrency

**Files:**
- Create: `backend/internal/storage/reserve_upload_space/service_test.go`
- Create: `backend/internal/storage/reserve_upload_space/service.go`

- [x] **Step 1: Write failing tests for reservation boundaries.**

```go
manager, err := New(fakeSpace{snapshot: Snapshot{
    AvailableBytes: MinimumFreeBytes + MaxAttachmentBytes,
    TotalBytes: 10 * gibibyte,
}})
reservation, err := manager.Reserve(context.Background())
if err != nil || reservation == nil { t.Fatal("exact boundary must admit") }
_, err = manager.Reserve(context.Background())
if !errors.Is(err, ErrInsufficientStorage) { t.Fatal("second upload crosses reserve") }
```

Also test that a 40-GiB filesystem preserves 4 GiB, concurrent callers cannot over-admit, and `Release` is idempotent.

- [x] **Step 2: Run the focused package before implementation.**

Run: `go test ./internal/storage/reserve_upload_space`

Expected: FAIL because `reserve_upload_space` does not exist.

- [x] **Step 3: Implement the reservation manager.**

```go
const MaxAttachmentBytes int64 = 25_000_000
const MinimumFreeBytes int64 = 2 * 1024 * 1024 * 1024

type Space interface { Snapshot(context.Context) (Snapshot, error) }

func (manager *Manager) Reserve(ctx context.Context) (*Reservation, error) {
    manager.mu.Lock()
    defer manager.mu.Unlock()
    snapshot, err := manager.space.Snapshot(ctx)
    if err != nil { return nil, err }
    if snapshot.AvailableBytes - protected(snapshot.TotalBytes) - manager.reserved < MaxAttachmentBytes {
        return nil, ErrInsufficientStorage
    }
    // Record exactly MaxAttachmentBytes and return a sync.Once-backed handle.
}
```

Calculate 10% with integer ceiling and subtraction checks so a malformed or very large filesystem value cannot overflow an admission decision.

- [ ] **Step 4: Run the focused package with the race detector.**

Run: `go test -race ./internal/storage/reserve_upload_space`

Expected: PASS.

Observed on this Windows workstation: the ordinary focused test passes, but
the race build cannot run because `CGO_ENABLED=1` requires `gcc` and no C
compiler is available on `PATH`. This check remains open until it is run in a
Go environment with a C toolchain.

### Task 2: Declare the interaction with staged writes

**Files:**
- Modify: `docs/ARCHITECTURE_AND_DATA.md`

- [x] **Step 1: Extend the attachment-state description.**

State that a full 25,000,000-byte reservation is taken before an untrusted stream starts, is counted with other in-process reservations and is released after finalisation or cleanup. This does not claim cross-process coordination or complete the upload endpoint.

- [x] **Step 2: Run backend and traceability checks.**

Run: `go test ./...`; `go vet ./...`; `powershell -ExecutionPolicy Bypass -File scripts/verify-spec-traceability.ps1`

Expected: all commands pass.

## Self-review

- The capacity decision never relies on client `Content-Length` and has no eviction, backup, TTL, public storage or message deletion behavior.
- It is deliberately a single-process ledger. Production filesystem sampling and a cross-process policy are separate integration work; a test fake does not prove a disk-capacity gate.
- ACL, attachment metadata, atomic final move, download authorization, previews and physical collection remain separate T-044 through T-047 leaves.
