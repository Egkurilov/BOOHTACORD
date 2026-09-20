# Repeatable Voice Lease Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a container restart safely apply the existing voice-lease schema migration when the column was installed by a prior release.

**Architecture:** The migration runner deliberately replays the embedded SQL files at service start. Preserve that behavior and make migration `0013` PostgreSQL-idempotent, so the desired column is created only if absent. A focused migration-package test guards the exact SQL invariant that caused the production deploy failure.

**Tech Stack:** Go 1.26, PostgreSQL SQL migrations, Go testing.

---

### Task 1: Make the migration repeatable and lock the regression down

**Files:**
- Modify: `backend/internal/database/migrate/migrations/0013_add_voice_lease_session_digest.sql:1`
- Modify: `backend/internal/database/migrate/run_test.go`
- Create: `docs/superpowers/plans/2026-09-18-repeatable-voice-lease-migration.md`

- [ ] **Step 1: Write the failing invariant test**

Add this test to `backend/internal/database/migrate/run_test.go`:

```go
func TestVoiceLeaseSessionDigestMigrationIsRepeatable(t *testing.T) {
	statement, err := files.ReadFile("migrations/0013_add_voice_lease_session_digest.sql")
	if err != nil {
		t.Fatalf("read migration: %v", err)
	}
	if !strings.Contains(string(statement), "ADD COLUMN IF NOT EXISTS session_token_digest") {
		t.Fatal("voice lease session digest migration must use ADD COLUMN IF NOT EXISTS")
	}
}
```

- [ ] **Step 2: Run the focused test to verify it fails**

Run: `go test ./internal/database/migrate -run TestVoiceLeaseSessionDigestMigrationIsRepeatable -count=1`

Expected: `FAIL` because migration 0013 uses `ADD COLUMN` without `IF NOT EXISTS`.

- [ ] **Step 3: Apply the minimal database change**

Replace the only statement in `backend/internal/database/migrate/migrations/0013_add_voice_lease_session_digest.sql` with:

```sql
ALTER TABLE voice_leases ADD COLUMN IF NOT EXISTS session_token_digest BYTEA NOT NULL REFERENCES sessions(token_digest) ON DELETE RESTRICT CHECK (octet_length(session_token_digest) = 32);
```

- [ ] **Step 4: Run focused and package tests**

Run:

```powershell
go test ./internal/database/migrate -count=1
```

Expected: `ok   voice-platform/backend/internal/database/migrate`.

- [ ] **Step 5: Verify the production-safe behavior with the deployment runner**

Run the migration container twice against the deployed database, then start only the API and proxy. Both migration runs must return zero and `https://v.bootybay.ru/api/v1/health` must return `{"status":"ok"}`. Do not run a down migration or alter application data.

- [ ] **Step 6: Inspect the scoped diff before any handoff**

Run:

```powershell
git diff --check -- backend/internal/database/migrate/migrations/0013_add_voice_lease_session_digest.sql backend/internal/database/migrate/run_test.go
git status --short
```

Expected: no whitespace errors; do not stage unrelated existing worktree changes.
