# Hidden attachment cleanup implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Physically remove a file after explicit TEXT or DM message deletion only when no live message references its attachment.

**Architecture:** A bounded operator run claims eligible attachment rows under PostgreSQL locks, turns them HIDDEN, and records a short claim lease. The existing anchored `os.Root` file adapter removes UUID-named files. A final transaction rechecks both TEXT and DM links, removes dead links and metadata, and writes a metadata-only audit row; an expired lease makes crashes retryable.

**Tech Stack:** Go 1.26, PostgreSQL, pgx, migration-backed integration tests.

---

### Task 1: Durable claim schema and repository

**Files:** `backend/internal/database/migrate/migrations/0037_add_hidden_attachment_cleanup_claim.sql`, `backend/internal/storage/cleanup_hidden_attachments/postgres/repository.go`, `backend/internal/storage/cleanup_hidden_attachments/postgres/integration_test.go`.

- [x] Write a PostgreSQL test with one deleted TEXT link, one deleted DM link, and live links in both tables. Assert only deleted-link candidates claim, and `ATTACHED` becomes `HIDDEN` with a claim token.
- [x] Run `go test ./internal/storage/cleanup_hidden_attachments/postgres -run TestHiddenCleanupAgainstPostgres -count=1`; expect red.
- [x] Add the migration's paired claim token/timestamp fields, claim query with `FOR UPDATE SKIP LOCKED`, and no-live-link predicates for both tables. Require a deleted link before claiming an `ATTACHED` row.
- [x] Re-run the targeted PostgreSQL test; expect green.

### Task 2: File removal and finalization

**Files:** `backend/internal/storage/cleanup_hidden_attachments/service.go`, `backend/internal/storage/cleanup_hidden_attachments/service_test.go`, `backend/internal/storage/cleanup_hidden_attachments/postgres/finalize.go`.

- [x] Write tests for file failure, finalization failure after file removal, expired claim retry, and a live link introduced before finalization; expect red.
- [x] Implement bounded service using BE-11's anchored UUID file adapter. On failed file removal release the claim when possible; on crash the claim expires. Finalization must recheck live TEXT/DM links and write `HIDDEN_ATTACHMENT_REMOVED` audit in one transaction with link and metadata deletion.
- [x] Re-run service and PostgreSQL tests; expect green, including separate TEXT/DM cases.

### Task 3: Operator entrypoint and deployment wiring

**Files:** `backend/cmd/cleanup_hidden_attachments/main.go`, `backend/cmd/cleanup_hidden_attachments/main_test.go`, `backend/Dockerfile`, `compose.yaml`.

- [x] Write CLI bound validation tests for `--limit=1..100`; expect red.
- [x] Implement one-shot CLI with a two-minute timeout and only count-based output; mount the same private attachment volume and database in an `operator` Compose service.
- [x] Run targeted Go tests, `go test ./internal/storage/... ./cmd/cleanup_hidden_attachments`, `docker compose --env-file .env.example -f compose.yaml --profile operator config --quiet`, and the Compose image verifier; expect green.

No automatic age-based deletion is introduced. The operator command is intentionally manual and bounded.
