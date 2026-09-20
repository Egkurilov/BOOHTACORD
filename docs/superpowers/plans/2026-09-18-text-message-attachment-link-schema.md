# Text Message Attachment Link Schema Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the durable schema needed to associate at most ten text-channel attachments with one message without ever reusing an attachment in another message.

**Architecture:** A `message_attachments` relation references only text `messages` and pre-existing `attachments`. Its primary key makes the relation idempotent per pair, its unique attachment key prevents cross-message reuse, and its per-message position constraint limits the legal ordinal range to ten values. A later command will atomically validate attachment owner, channel and `UNATTACHED` state before inserting links and transitioning state; this schema alone grants no access.

**Tech Stack:** PostgreSQL versioned SQL migrations embedded by Go, pgx migration-runner unit test.

---

### Task 1: Versioned link-table migration

**Files:**
- Create: `backend/internal/database/migrate/migrations/0024_create_message_attachments.sql`
- Modify: `backend/internal/database/migrate/run_test.go`

- [x] **Step 1: Extend the migration-runner test before adding the SQL.** Append an expected 24th statement containing `CREATE TABLE IF NOT EXISTS message_attachments`, `PRIMARY KEY (message_id, attachment_id)`, `UNIQUE (attachment_id)`, and a `position BETWEEN 0 AND 9` check.

- [x] **Step 2: Run `go test ./internal/database/migrate` from `backend`.** Observed the expected count failure: 23 statements rather than 24.

- [x] **Step 3: Create migration 0024.** Define `message_id UUID NOT NULL REFERENCES messages(id) ON DELETE RESTRICT`, `attachment_id UUID NOT NULL UNIQUE REFERENCES attachments(id) ON DELETE RESTRICT`, `position SMALLINT NOT NULL CHECK (position BETWEEN 0 AND 9)`, `PRIMARY KEY (message_id, attachment_id)`, and `UNIQUE (message_id, position)`.

- [x] **Step 4: Run the migration test.** PASS with 24 embedded statements.

### Task 2: State-machine documentation and SQL syntax proof

**Files:**
- Modify: `docs/ARCHITECTURE_AND_DATA.md`
- Modify: `docs/superpowers/plans/2026-09-18-text-message-attachment-link-schema.md`

- [x] **Step 1: Document the relation's limits.** State that it is text-message-only, prevents one attachment from being linked twice, orders a maximum of ten attachments, and neither changes state nor authorizes downloading by itself.

- [x] **Step 2: Syntax-check migrations 0023 and 0024 inside a rolled-back transaction against the private deployment PostgreSQL container.** PASS on 2026-09-18: `BEGIN`, two `CREATE TABLE` results, then `ROLLBACK`; no schema persisted.

- [x] **Step 3: Run `go test ./...` and `go vet ./...` from `backend`, then `scripts/verify-spec-traceability.ps1`.** PASS on 2026-09-18; traceability reports 39 referenced requirements. Inspect changed file sizes and `git status --short` without staging or committing.

- [x] **Step 4: Mark only successful checks complete in this plan.** All planned checks passed; the initial hard-coded database-role invocation was retried through the container's configured credentials and did not execute DDL.
