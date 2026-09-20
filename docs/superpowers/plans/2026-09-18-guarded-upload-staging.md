# Guarded Upload Staging Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hold one maximum-size reservation through a staged upload and recheck free attachment space before every source read, removing the temporary file when the capacity guard fails.

**Architecture:** `write_upload` gains an optional pre-read guard while retaining its current `Write` API. `reserve_upload_space.Manager.Confirm` checks the current `Bavail` snapshot against all held reservations. `stage_upload` composes one concrete manager and writer: it reserves first, writes under `Confirm`, and releases in every result path; it still has no HTTP, database, ACL or final attachment state.

**Tech Stack:** Go standard library, focused Go unit tests.

---

### Task 1: Make the byte writer invoke a non-nil capacity guard

**Files:**
- Modify: `backend/internal/storage/write_upload/service.go`
- Create: `backend/internal/storage/write_upload/guard.go`
- Create: `backend/internal/storage/write_upload/guard_test.go`

- [x] **Step 1: Write a failing cleanup test for a guard error.**

```go
_, err = writer.WriteGuarded(context.Background(), strings.NewReader("bytes"), func(context.Context) error {
    return errNoCapacity
})
if !errors.Is(err, errNoCapacity) { t.Fatal(err) }
assertDirectoryEmpty(t, directory)
```

- [x] **Step 2: Run the focused package before implementation.**

Run: `go test ./internal/storage/write_upload`

Expected: FAIL because `WriteGuarded` is undefined.

- [x] **Step 3: Add the guarded write path without weakening `Write`.**

```go
type Guard func(context.Context) error

func (writer Writer) Write(ctx context.Context, source io.Reader) (Result, error) {
    return writer.write(ctx, source, nil)
}

func (writer Writer) WriteGuarded(ctx context.Context, source io.Reader, guard Guard) (Result, error) {
    return writer.write(ctx, source, guard)
}
```

Call a non-nil guard in `contextReader.Read` after checking the context and before calling the untrusted source. Any guard failure follows the existing deferred close/remove path.

- [x] **Step 4: Run the focused writer tests.**

Run: `go test ./internal/storage/write_upload`

Expected: PASS.

### Task 2: Recheck active reservations against a fresh snapshot

**Files:**
- Create: `backend/internal/storage/reserve_upload_space/confirm.go`
- Create: `backend/internal/storage/reserve_upload_space/confirm_test.go`

- [x] **Step 1: Write failing tests for a full reservation that later crosses the reserve.**

```go
space := &sequenceSpace{snapshots: []Snapshot{admissible, belowReserve}}
manager, _ := New(space)
reservation, _ := manager.Reserve(context.Background())
defer reservation.Release()
if !errors.Is(manager.Confirm(context.Background()), ErrInsufficientStorage) { t.Fatal("must stop stream") }
```

- [x] **Step 2: Implement `Confirm`.**

```go
func (manager *Manager) Confirm(ctx context.Context) error {
    manager.mu.Lock()
    defer manager.mu.Unlock()
    snapshot, err := manager.space.Snapshot(ctx)
    if err != nil { return err }
    minimum, err := protectedBytes(snapshot)
    if err != nil || snapshot.AvailableBytes < minimum { return ErrInsufficientStorage }
    if snapshot.AvailableBytes-minimum < manager.reserved { return ErrInsufficientStorage }
    return nil
}
```

Preserve the existing reservation on a failed confirmation; its owner still releases it through the normal deferred path.

- [x] **Step 3: Run reservation tests.**

Run: `go test ./internal/storage/reserve_upload_space`

Expected: PASS.

### Task 3: Compose reserve, guarded write and release

**Files:**
- Create: `backend/internal/storage/stage_upload/service.go`
- Create: `backend/internal/storage/stage_upload/service_test.go`

- [x] **Step 1: Write a failing test for cleanup after a later capacity failure.**

```go
_, err = stager.Stage(context.Background(), &twoReadSource{})
if !errors.Is(err, reserveuploadspace.ErrInsufficientStorage) { t.Fatal(err) }
assertDirectoryEmpty(t, directory)
if manager.ReservedBytes() != 0 { t.Fatal("reservation leaked") }
```

Also cover a successful staging result and an admission refusal that creates no temporary file.

- [x] **Step 2: Implement the one-operation service.**

```go
func (stager Service) Stage(ctx context.Context, source io.Reader) (writeupload.Result, error) {
    reservation, err := stager.manager.Reserve(ctx)
    if err != nil { return writeupload.Result{}, err }
    defer reservation.Release()
    return stager.writer.WriteGuarded(ctx, source, stager.manager.Confirm)
}
```

- [x] **Step 3: Run the new staging package.**

Run: `go test ./internal/storage/stage_upload`

Expected: PASS.

### Task 4: Record the behavior and validate the backend

**Files:**
- Modify: `docs/ARCHITECTURE_AND_DATA.md`

- [x] **Step 1: Document pre-read space confirmation and the current boundary.**

State that capacity is sampled before every stream read while a full reservation is held; no claim of cross-process locking or complete upload API is made.

- [x] **Step 2: Run backend checks.**

Run: `go test ./...`; `go vet ./...`; `powershell -ExecutionPolicy Bypass -File scripts/verify-spec-traceability.ps1`

Expected: PASS.

## Self-review

- The source cannot add a byte after an observed capacity failure, and the existing writer cleanup removes the incomplete file.
- A temporary-file result is still private and unattached; a successful stage does not create a message, attachment row, public URL or download capability.
- `statfs` sampling is not a cross-process lock, so external writers can still race it; the product must not treat this leaf as a completed disk-capacity or storage security gate.
