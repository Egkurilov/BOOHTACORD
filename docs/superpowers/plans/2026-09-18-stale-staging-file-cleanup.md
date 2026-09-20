# Stale Staging File Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Safely remove only incomplete `upload-*.part` files older than one hour from the private staging directory.

**Architecture:** A small filesystem leaf receives a resolved staging directory and caller-provided cutoff. It lists only direct children, skips symlinks, directories, unexpected names and files at/after the cutoff, then deletes matching old regular files with exact paths. It never enters `unattached`, reads PostgreSQL, determines attachment liveness, or runs from the API process in this packet.

**Tech Stack:** Go standard library filesystem APIs and Go tests.

---

### Task 1: Bounded staging-file collector

**Files:**
- Create: `backend/internal/storage/cleanup_stale_staging_files/service.go`
- Create: `backend/internal/storage/cleanup_stale_staging_files/service_test.go`

- [x] **Step 1: Write failing safety tests**

```go
removed, err := New(staging).RemoveBefore(cutoff)
if err != nil || removed != 1 { t.Fatal(...) }
if _, err := os.Stat(oldPart); !errors.Is(err, os.ErrNotExist) { t.Fatal(err) }
if _, err := os.Stat(recentPart); err != nil { t.Fatal(err) }
if _, err := os.Stat(unexpectedFile); err != nil { t.Fatal(err) }
```

Create an old `upload-*.part`, a recent part, an old non-matching file, and a symlink when supported. Assert invalid/missing directory returns `ErrInvalidStagingDirectory`.

- [x] **Step 2: Run the focused test and verify it fails before the package exists**

Run: `go test ./internal/storage/cleanup_stale_staging_files`

Expected: FAIL with missing `New`/`ErrInvalidStagingDirectory`.

- [x] **Step 3: Implement direct-child, regular-file-only deletion**

```go
func (service Service) RemoveBefore(cutoff time.Time) (int, error) {
    entries, err := os.ReadDir(service.directory)
    for _, entry := range entries {
        if entry.IsDir() || entry.Type()&os.ModeSymlink != 0 || !strings.HasPrefix(entry.Name(), "upload-") || !strings.HasSuffix(entry.Name(), ".part") { continue }
        info, err := entry.Info()
        if err != nil || !info.Mode().IsRegular() || !info.ModTime().Before(cutoff) { continue }
        if err := os.Remove(filepath.Join(service.directory, entry.Name())); err != nil { return removed, err }
        removed++
    }
}
```

Resolve the provided directory with `filepath.EvalSymlinks`, require an existing directory, and reject a zero cutoff. Never recurse or follow entry symlinks.

- [x] **Step 4: Run focused test, full Go test and vet**

Run: `go test ./internal/storage/cleanup_stale_staging_files; go test ./...; go vet ./...`

Expected: all exit 0.

### Task 2: Record the deliberately narrow boundary

**Files:**
- Modify: `TODO.md: T-046`
- Modify: `docs/superpowers/plans/2026-09-18-stale-staging-file-cleanup.md`

- [x] **Step 1: Update TODO and evidence**

State that stale staging cleanup is implemented as a reusable primitive but is not scheduled or invoked in production yet. Leave unattached PostgreSQL cleanup, audited physical removal and production scheduling open.

- [x] **Step 2: Inspect diff and preserve shared worktree**

Run: `git diff --check -- backend/internal/storage/cleanup_stale_staging_files TODO.md; git status --short`

Mark executed steps `[x]`; do not stage or commit shared-worktree files.

## Self-review

- **Spec coverage:** Begins the REQ-STORAGE-03 permitted cleanup without deleting published history or an unattached object.
- **Safety:** No recursion, no glob delete, no path from untrusted input, no symlink traversal, no DB mutation, and no API startup task.
- **Intentional gap:** This does not satisfy or invoke unattached object cleanup. That later leaf must atomically prove `UNATTACHED` plus no live message link, record its result, and coordinate DB/file removal.

## Execution evidence

- Failing-first run: the test failed because `New`, `ErrInvalidStagingDirectory`, and `ErrInvalidCutoff` were absent.
- Focused check: `go test ./internal/storage/cleanup_stale_staging_files` passed; it proves deletion of one old part file and preservation of a cutoff-equal file, unexpected name and symlink.
- Native validation: `go test ./...` and `go vet ./...` passed.
- The primitive is not wired into API startup, Compose or a production job; no filesystem cleanup was invoked on the server. Shared-worktree files remain unstaged and uncommitted.
