# Finalize Staged Text Attachment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move a validated staged text-channel upload to private unattached storage and create its metadata only while the owner and text channel are still eligible.

**Architecture:** A filesystem leaf permits moves only from the configured staging directory to the configured unattached directory, naming the final object with a generated UUID. A service generates attachment and storage IDs, repeats the active-user/unarchived-TEXT-channel predicate inside the insert, and removes the moved object if persistence fails. No public path, download endpoint, message-link mutation, or DM path is introduced.

**Tech Stack:** Go 1.26, standard-library filesystem primitives, UUID-style random IDs, PostgreSQL through pgx.

---

### Task 1: Private final-object mover

**Files:**
- Create: `backend/internal/storage/finalize_staged_text_attachment/files.go`
- Create: `backend/internal/storage/finalize_staged_text_attachment/files_test.go`

- [x] **Step 1: Write failing filesystem tests.** Create staging and unattached temporary directories; write `stage/upload.part`; call `NewFileStore(staging, unattached).Move(stagePath, key)` and assert source absence, byte-preserving destination at `unattached/key`, and rejection of a path outside staging.

- [x] **Step 2: Run `go test ./internal/storage/finalize_staged_text_attachment` from `backend`.** Observed the expected compilation failure for the absent filesystem and service symbols.

- [x] **Step 3: Implement `FileStore`.** Validate both existing distinct directories, resolve the supplied temporary path with `filepath.Rel`, reject parent traversal, require a UUID storage key, use `os.Rename` within the configured volume, and expose `Remove(key)` only for service rollback.

- [x] **Step 4: Run the package test.** PASS: `go test ./internal/storage/finalize_staged_text_attachment/...`.

### Task 2: Atomic authorization-bound metadata persistence

**Files:**
- Create: `backend/internal/storage/finalize_staged_text_attachment/service.go`
- Create: `backend/internal/storage/finalize_staged_text_attachment/id.go`
- Create: `backend/internal/storage/finalize_staged_text_attachment/service_test.go`
- Create: `backend/internal/storage/finalize_staged_text_attachment/postgres/repository.go`
- Create: `backend/internal/storage/finalize_staged_text_attachment/postgres/repository_test.go`
- Create: `backend/internal/storage/finalize_staged_text_attachment/postgres/pool_database.go`

- [x] **Step 1: Write failing service tests.** With a fake store and mover, assert a successful finalization generates distinct UUID attachment/storage keys and returns only metadata; assert an unavailable target after moving calls rollback removal; assert malformed IDs, empty/NUL names, and out-of-range byte size do not invoke storage. The concrete file-store test enforces the trusted staging path.

- [x] **Step 2: Write failing repository tests.** Assert the insert receives ID, actor ID, channel ID, original name, storage key and byte size; inspect its statement for `users.blocked_at IS NULL`, `channels.kind = 'TEXT'`, `channels.archived_at IS NULL`, and an insert selected from that target CTE. Map `pgx.ErrNoRows` to `ErrTargetUnavailable`.

- [x] **Step 3: Run `go test ./internal/storage/finalize_staged_text_attachment/...` from `backend`.** Observed the expected compilation failure before the implementation was added.

- [x] **Step 4: Implement the service and repository.** The service validates values before generating IDs, moves the bytes first, inserts an `UNATTACHED` row whose CTE rechecks the caller and target, and removes the destination on any insert error. The file-store is the trusted-stage boundary; the repository offers neither a role bypass nor a public URL.

- [x] **Step 5: Run the focused package tests.** PASS: `go test ./internal/storage/finalize_staged_text_attachment/...`.

### Task 3: Document the completed state transition and validate

**Files:**
- Modify: `docs/ARCHITECTURE_AND_DATA.md`
- Modify: `docs/superpowers/plans/2026-09-18-finalize-staged-text-attachment.md`

- [x] **Step 1: Document the precise ordering.** State that finalization is an atomic filesystem move followed by ACL-bound metadata insertion, that failure removes the private destination, and that a crash candidate remains non-public and is eligible only for the permitted unattached cleanup.

- [x] **Step 2: Mark implementation and focused tests complete in this plan.** The full-suite and vet command remain pending until the final validation step.

- [x] **Step 3: Run `go test ./...` and `go vet ./...` from `backend`.** PASS on 2026-09-18; inspect changed file sizes and `git status --short` without staging or committing unrelated work.
