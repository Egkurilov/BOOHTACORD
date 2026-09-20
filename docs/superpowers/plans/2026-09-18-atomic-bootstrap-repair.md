# Atomic Bootstrap Repair Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent a first-administrator bootstrap from creating an unlinked administrator, and repair the single proven unlinked production state atomically during migration.

**Architecture:** Replace the one-statement data-modifying CTE with an advisory-lock-protected PostgreSQL transaction. It claims/locks bootstrap state, creates the administrator, writes the state link and audit row, then commits as one unit. A one-time idempotent migration links only an existing singleton state with a null administrator to exactly one active administrator and writes the missing initial-bootstrap audit event.

**Tech Stack:** Go 1.26, pgx v5/pgxpool, PostgreSQL, Docker Compose migrations, Go unit tests.

---

### Task 1: Pin the regression with focused repository tests

**Files:**
- Modify: `backend/internal/identity/bootstrap_administrator/postgres/repository_test.go`
- Modify: `backend/internal/database/migrate/run_test.go`

- [x] **Step 1: Write a failing test for transactional initial bootstrap.**

Replace the fake single-row database with a fake transaction and assert the following ordered effects: transaction advisory lock, missing bootstrap-state read, bound administrator insert, singleton state insert with the new account ID, initial audit insert, then commit. Assert rollback and no commit when the state query says bootstrap is already complete.

- [x] **Step 2: Run the focused repository test before implementation.**

Run:

```powershell
Push-Location backend
go test ./internal/identity/bootstrap_administrator/postgres -run TestRepository
Pop-Location
```

Expected: FAIL because the current repository only has `QueryRow` and the CTE cannot model a locked multi-step commit.

- [x] **Step 3: Extend the migration runner expectation.**

Add the expected `0025_repair_incomplete_bootstrap_state.sql` entry with the fragments `UPDATE bootstrap_state`, `administrator_id IS NULL`, `COUNT(*) = 1`, and `INSERT INTO audit_events`.

### Task 2: Implement atomic future bootstrap

**Files:**
- Modify: `backend/internal/identity/bootstrap_administrator/postgres/repository.go`
- Modify: `backend/internal/identity/bootstrap_administrator/postgres/pool_database.go`
- Modify: `backend/internal/identity/bootstrap_administrator/service.go`
- Modify: `backend/cmd/bootstrap_admin/main.go`

- [x] **Step 1: Add the incomplete-state domain outcome.**

Define `ErrBootstrapIncomplete` beside `ErrAlreadyInitialized`. The CLI must return a bounded operational error for it rather than claiming that no account changed.

- [x] **Step 2: Implement the locked transaction.**

Use a dedicated `pg_advisory_xact_lock` key. Under that lock, query `administrator_id IS NOT NULL` from the singleton state with `FOR UPDATE`. If no row exists, insert the user with its bound ID/hash, insert `bootstrap_state(singleton, administrator_id)` using that ID, insert the `INITIAL_ADMINISTRATOR_CREATED` audit event, and commit. If state exists with an administrator, return `ErrAlreadyInitialized`; if it exists without one, return `ErrBootstrapIncomplete`; every error before commit rolls back.

- [x] **Step 3: Adapt the pgx pool adapter.**

Expose `Begin`, advisory locking, `QueryRow`, `Exec`, commit and rollback through the repository's local interfaces. Treat `pgx.ErrTxClosed` rollback as harmless, following the established administrator-recovery adapter.

- [x] **Step 4: Run the focused test.**

Run:

```powershell
Push-Location backend
go test ./internal/identity/bootstrap_administrator/... -count=1
Pop-Location
```

Expected: PASS; the test proves lock, account/state/audit writes and commit/rollback outcomes without revealing a password hash.

### Task 3: Repair only the proven incomplete state

**Files:**
- Create: `backend/internal/database/migrate/migrations/0025_repair_incomplete_bootstrap_state.sql`
- Modify: `backend/internal/database/migrate/run_test.go`

- [x] **Step 1: Add the idempotent repair migration.**

Write one CTE statement that updates `bootstrap_state.administrator_id` only when its singleton row has a null administrator and exactly one unblocked `ADMINISTRATOR` exists. Insert `INITIAL_ADMINISTRATOR_CREATED` with that account as `target_user_id` only when that update returned a row. The statement must have no login, password or token literal and re-running it must have no effect after repair.

- [x] **Step 2: Run the migration package test.**

Run:

```powershell
Push-Location backend
go test ./internal/database/migrate -count=1
Pop-Location
```

Expected: PASS with the 25th embedded migration asserted.

### Task 4: Validate, build, and repair the deployed state

**Files:**
- Modify: `docs/ADMIN_OPERATIONS.md`
- Modify: `evidence/poc-01-preflight-production-2026-09-18.json`

- [x] **Step 1: Document the bounded incomplete-bootstrap operator outcome.**

State that a singleton bootstrap state without an administrator is an incomplete deployment state: deploy the repair migration before retrying, and do not run recovery or create another administrator manually.

- [x] **Step 2: Run native checks before deployment.**

Run:

```powershell
Push-Location backend
go test ./...
go vet ./...
go build ./cmd/api ./cmd/migrate ./cmd/bootstrap_admin ./cmd/recover_admin
Pop-Location
scripts/verify-spec-traceability.ps1
git diff --check
```

Expected: all commands exit `0`.

- [ ] **Step 3: Deploy a uniquely tagged API image, run migration before service replacement, and verify aggregates.**

Copy only the changed backend/Dockerfile inputs to `/opt/voice-platform`, rebuild the pinned API image, run the `migrate` service, then recreate API/web/proxy only when their source/image changes require it. Verify without reading IDs or secrets: one bootstrap state linked to one administrator, one initial audit event, public health `200`, and the `owner` login works with the password that remains solely in the local clipboard.

- [ ] **Step 4: Mark this plan complete only after the deployment checks pass.**

Replace the task checkboxes above with `[x]` only after focused tests, full native checks, migration, public health and aggregate repair verification all pass.

**Coverage review:** This packet fixes the observed data-integrity failure in REQ-AUTH-04 and preserves its no-first-registration and no-secret-logging rules. It does not create a participant account, a channel, a physical observer or Windows/macOS media evidence; POC-01 remains open after the repair.
