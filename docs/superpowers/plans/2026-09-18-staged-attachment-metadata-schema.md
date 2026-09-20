# Staged Attachment Metadata Schema Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist private staged-attachment metadata that binds an upload to its owner and exactly one target conversation before any message attaches or exposes the file.

**Architecture:** A single immutable PostgreSQL migration creates `attachments`. It stores a random UUID `storage_key` rather than a filesystem path, original filename as private metadata, measured size and `UNATTACHED`/`ATTACHED`/`HIDDEN` state. Exactly one of `channel_id` and `direct_message_id` is required by a database constraint; future command SQL supplies the conversation ACL and future finalisation moves the random object atomically to the private attachment volume.

**Tech Stack:** PostgreSQL DDL migration, embedded-migration Go unit test, architecture documentation.

---

### Task 1: Specify the migration receipt before creating it

**Files:**
- Modify: `backend/internal/database/migrate/run_test.go`
- Create: `backend/internal/database/migrate/migrations/0023_create_attachments.sql`

- [x] **Step 1: Extend the embedded-migration test with the expected attachment statement.**

```go
if len(executor.statements) != 23 ||
    !strings.Contains(executor.statements[22], "CREATE TABLE IF NOT EXISTS attachments") ||
    !strings.Contains(executor.statements[22], "attachments_exactly_one_target") ||
    !strings.Contains(executor.statements[22], "storage_key UUID NOT NULL UNIQUE") {
    t.Fatalf("statements = %#v", executor.statements)
}
```

- [x] **Step 2: Run the migration package before implementation.**

Run: `go test ./internal/database/migrate`

Expected: FAIL because the 23rd embedded migration does not exist.

- [x] **Step 3: Add one DDL statement in migration 0023.**

```sql
CREATE TABLE IF NOT EXISTS attachments (
    id UUID PRIMARY KEY,
    owner_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    channel_id UUID REFERENCES channels(id) ON DELETE RESTRICT,
    direct_message_id UUID REFERENCES direct_messages(id) ON DELETE RESTRICT,
    original_name TEXT NOT NULL CHECK (char_length(original_name) > 0),
    storage_key UUID NOT NULL UNIQUE,
    byte_size BIGINT NOT NULL CHECK (byte_size BETWEEN 0 AND 25000000),
    state TEXT NOT NULL CHECK (state IN ('UNATTACHED', 'ATTACHED', 'HIDDEN')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    attached_at TIMESTAMPTZ,
    hidden_at TIMESTAMPTZ,
    CONSTRAINT attachments_exactly_one_target CHECK (
        (channel_id IS NOT NULL AND direct_message_id IS NULL) OR
        (channel_id IS NULL AND direct_message_id IS NOT NULL)
    )
);
```

Do not store a public URL, an absolute temporary path, an object-store key or a backup reference.

- [x] **Step 4: Run the focused migration test.**

Run: `go test ./internal/database/migrate`

Expected: PASS.

### Task 2: State the staged-metadata boundary

**Files:**
- Modify: `docs/ARCHITECTURE_AND_DATA.md`

- [x] **Step 1: Document ownership, target and state before attachment.**

State that an unattached record has exactly one private target conversation and a random storage key; it does not confer download access or claim that bytes have been moved.

- [x] **Step 2: Run backend validation.**

Run: `go test ./...`; `go vet ./...`; `powershell -ExecutionPolicy Bypass -File scripts/verify-spec-traceability.ps1`

Expected: PASS.

## Self-review

- The schema does not grant ACL by identifier and contains no administrator bypass.
- `storage_key` is a private random filename component, never a response URL or an authority token.
- Staging ACL, file finalisation, message attachment limits, direct-message handling, downloads, previews and collection remain separate leaves.
