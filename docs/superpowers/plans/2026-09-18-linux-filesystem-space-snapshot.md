# Linux Filesystem Space Snapshot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide the reservation ledger with a real Linux filesystem snapshot for the configured private attachment volume.

**Architecture:** `Filesystem` implements the existing `reserve_upload_space.Space` interface through Linux `statfs`, reporting available blocks (`Bavail`) and total blocks (`Blocks`) in checked byte units. The code is Linux-only because the deployed API uses Linux containers; it will be verified by cross-building the package on Windows and running its Linux test binary on the deployment host without touching Compose or the running containers.

**Tech Stack:** Go standard library `syscall.Statfs`, Go build constraints, remote Linux test binary.

---

### Task 1: Define the Linux snapshot contract

**Files:**
- Create: `backend/internal/storage/reserve_upload_space/filesystem_linux_test.go`
- Create: `backend/internal/storage/reserve_upload_space/filesystem_linux.go`

- [x] **Step 1: Write Linux-only failing tests.**

```go
filesystem, err := NewFilesystem(t.TempDir())
snapshot, err := filesystem.Snapshot(context.Background())
if err != nil || snapshot.TotalBytes <= 0 || snapshot.AvailableBytes < 0 || snapshot.AvailableBytes > snapshot.TotalBytes {
    t.Fatalf("snapshot = %#v, error = %v", snapshot, err)
}
```

Also reject an empty path before calling the operating system.

- [x] **Step 2: Cross-compile the package before implementation.**

Run: `GOOS=linux GOARCH=amd64 go test -c ./internal/storage/reserve_upload_space`

Expected: FAIL because `NewFilesystem` does not exist for Linux.

- [x] **Step 3: Implement the Linux-only adapter.**

```go
//go:build linux

func (filesystem Filesystem) Snapshot(ctx context.Context) (Snapshot, error) {
    if err := ctx.Err(); err != nil { return Snapshot{}, err }
    var stats syscall.Statfs_t
    if err := syscall.Statfs(filesystem.path, &stats); err != nil { return Snapshot{}, err }
    return Snapshot{AvailableBytes: checkedBytes(stats.Bavail, stats.Bsize), TotalBytes: checkedBytes(stats.Blocks, stats.Bsize)}, nil
}
```

Reject invalid paths, zero block size and products that do not fit `int64`; never use `Bfree`, which includes blocks unavailable to ordinary users.

- [x] **Step 4: Cross-build then execute the Linux test binary on the existing deployment host.**

Build the test binary in a temporary local path, copy it to a unique `/tmp` path over SSH, execute it as `shaneque`, then remove exactly that temporary remote and local binary.

Expected: Linux snapshot tests PASS. No Compose command, source transfer, environment file, container, volume or firewall rule changes.

### Task 2: Record scope and validate project checks

**Files:**
- Modify: `docs/ARCHITECTURE_AND_DATA.md`

- [x] **Step 1: State that production snapshots use Linux `Bavail`, not `Bfree`.**

Explain that this only supplies input to the in-process ledger; it neither proves capacity under external writers nor completes the upload workflow.

- [x] **Step 2: Run native checks.**

Run: `go test ./...`; `go vet ./...`; `powershell -ExecutionPolicy Bypass -File scripts/verify-spec-traceability.ps1`

Expected: PASS.

## Self-review

- This adapter reads the private volume only and creates no storage object, backup, snapshot or public endpoint.
- The remote verification runs a temporary test executable and does not touch the deployed application source or runtime.
- Writer integration, multipart parsing, ACL, attachment rows, final atomic move and cleanup remain independent future leaves.
