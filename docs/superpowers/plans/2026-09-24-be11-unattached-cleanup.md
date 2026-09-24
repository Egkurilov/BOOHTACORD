# BE-11 Unattached Attachment Cleanup Implementation Plan

> **For agentic workers:** Execute the steps inline. The user has already requested implementation and assigned a separate agent to this leaf.

**Goal:** Clean up attachment objects older than 24 hours that were never linked to a message, without deleting a live attachment during a concurrent send.

**Architecture:** A bounded operator command claims eligible `UNATTACHED` rows by changing them to `DELETING` under PostgreSQL row locks. `DELETING` rows are retried after crashes or filesystem failures. The file is removed using an anchored `os.Root`; only then is its metadata deleted. A separate, key-specific recovery mode handles a file left by a crash between the filesystem move and metadata insert. Audit records contain counts only.

**Tech Stack:** Go 1.26, pgx/PostgreSQL, local private attachment volume, native Go tests.

---

### Task 1: Durable claim contract

**Files:** Create `backend/internal/database/migrate/migrations/0031_add_attachment_deleting_state.sql`; modify `backend/internal/database/migrate/run_test.go`.

- [x] Add a migration assertion to the embedded-migration test and observe the missing-migration failure with `go test ./internal/database/migrate`.
- [x] Extend the attachment state and timestamp constraints with `DELETING`, leaving `attached_at` and `hidden_at` null, and add a partial index for retrying claimed rows.
- [x] Re-run `go test ./internal/database/migrate`; PASS, including an isolated PostgreSQL migration test.

### Task 2: Claim and finalize eligible rows

**Files:** Create `backend/internal/storage/cleanup_unattached_attachments/postgres/repository.go`, `backend/internal/storage/cleanup_unattached_attachments/postgres/repository_test.go`.

- [x] Test query guards: 24-hour cutoff, `UNATTACHED` or retry `DELETING`, `FOR UPDATE SKIP LOCKED`, TEXT live-link exclusion, optional DM live-link exclusion when the DM link table exists, bounded `LIMIT`, and finalize restricted to `DELETING`.
- [x] Implement `Claim`, `Finalize`, `Exists`, and count-only audit on pgxpool. The claim statement decides the optional DM table before constructing its SQL.
- [x] Run `go test ./internal/storage/cleanup_unattached_attachments/postgres`; PASS, including an isolated PostgreSQL attach race test.

### Task 3: Private file removal and retry behavior

**Files:** Create `backend/internal/storage/cleanup_unattached_attachments/service.go`, `backend/internal/storage/cleanup_unattached_attachments/files.go`, and focused `*_test.go` files.

- [x] Test stale eligibility, claim versus attach, failure after claim, failure after unlink, missing-file retry, live-link exclusion, UUID/path/symlink rejection, and orphan recovery cutoff using disposable temp files.
- [x] Implement a bounded `Run(ctx, now, limit)` and a key-specific `RecoverOrphan(ctx, key, now)`; validate `now`, enforce `1 <= limit <= 100`, and use `os.OpenRoot` plus `Lstat` before `Remove`.
- [x] Run `go test ./internal/storage/cleanup_unattached_attachments/...`; PASS.

### Task 4: Operator entrypoint and verification

**Files:** Create `backend/cmd/cleanup_unattached_attachments/main.go` and its argument tests.

- [x] Test that the operator requires valid configuration and supports a bounded cleanup run or explicit orphan key recovery.
- [x] Wire `DATABASE_URL` and absolute `ATTACHMENTS_DIRECTORY/unattached` to the service; print only counts and generic errors, never keys or attachment content.
- [x] Run `go test ./cmd/cleanup_unattached_attachments ./internal/storage/cleanup_unattached_attachments/... ./internal/database/migrate` and `go vet` on the same packages; PASS.

**Safety invariant:** The DB state changes to `DELETING` before any file unlink, so an attach can succeed only before the claim or fail after it. A crash before unlink leaves a retryable row; a crash after unlink leaves a retryable row with an absent file. The uploaded-file orphan mode checks absence of DB metadata and a filesystem mtime older than 24 hours before unlinking one explicitly named UUID file.

**Operator use:** Apply migrations first, then run `go run ./cmd/cleanup_unattached_attachments --limit=100` from `backend/` with `DATABASE_URL` and absolute `ATTACHMENTS_DIRECTORY`. Re-run until the claimed count is zero. For a file stranded between move and metadata insert, identify its UUID filename in the private `unattached/` directory and run `go run ./cmd/cleanup_unattached_attachments --orphan-key=<uuid>`; this mode checks its age and absence of metadata before removing it. The operator never prints the key or file contents.
