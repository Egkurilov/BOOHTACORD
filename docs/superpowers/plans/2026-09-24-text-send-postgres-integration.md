# Text Send PostgreSQL Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Verify and harden text-message `client_message_id` idempotency against real PostgreSQL, including overlapping retries.

**Architecture:** Preserve the existing atomic SQL command and unique constraint. If a competing insert wins the same author/channel/client key, recover only that named unique violation with a fresh SELECT of the authoritative row. Run integration tests against a disposable PostgreSQL 17.6 instance and a randomly named schema, never production data.

**Tech Stack:** Go 1.26, pgx v5, PostgreSQL 17.6, GitVerse Actions, GitHub-compatible CI workflow syntax.

---

## Route brief

- Classification: `split_first`; medium packet; leaf: common TEXT-message idempotent create in `backend/internal/chat/create_text_message/postgres`.
- Requirement: REQ-CHAT-01 retry after lost acknowledgement returns the same logical message without duplication.
- Existing edge: `Service.Create` calls `Repository.Create`; migrations embed in `internal/database/migrate`; current repo SQL returns an existing row for a serial retry, while a concurrent insert can still surface the named unique-constraint error.
- Files: `backend/internal/chat/create_text_message/postgres/repository.go`, its unit and integration tests; new `scripts/test-backend-with-postgres.sh`; `.github/workflows/ci.yml`; `.gitverse/workflows/deploy-production.yaml`; `TODO.md`.
- Safety: integration URL must point to loopback only; each test creates/drops only a generated `voice_it_<uuid>` schema; test container has no persistent volume; no production URL or credentials.
- Native checks: focused repository tests and all Go tests; the integration runner with PostgreSQL 17.6; both workflow YAML parses, compose-image checks, contract traceability, and `git diff --check`.
- Stop when serial and overlapping retries return the first row, unrelated unique conflicts remain errors, real migration-backed PostgreSQL tests execute in CI, and all available checks pass. Local PostgreSQL execution may remain `NOT_RUN` when Docker is unavailable; do not report it as PASS.

## Execution steps

1. Add a unit test that makes the first database call return `pgconn.PgError{Code: "23505", ConstraintName: "messages_author_channel_client_message_unique"}` and the second return the original row; assert the repository returns that row after exactly two calls. Add a second case proving another constraint name is not retried. Run `go test ./internal/chat/create_text_message/postgres -run 'TestRepository(RecoversConcurrentIdempotencyConflict|DoesNotRecoverOtherUniqueConflict)$'` and observe failure before implementation.
2. Implement recovery only for SQLSTATE `23505` and the named message idempotency constraint. Query by `(author_id, channel_id, client_message_id)` in a new statement, return its authoritative row, and preserve the original error if no row exists.
3. Add a migration-backed integration test activated only by `VOICE_PLATFORM_TEST_DATABASE_URL`. Reject non-loopback hosts; create a fresh generated schema; set `search_path`; run all embedded migrations; seed one member/category/TEXT channel; assert first send plus serial retry return identical IDs/body and leave one row. Launch two concurrent creates with the same idempotency key but different proposed IDs; assert both calls return the same committed row and count remains one. Cleanup only the generated schema.
4. Add `scripts/test-backend-with-postgres.sh`: run disposable `postgres:17.6-alpine`, wait for `pg_isready`, export the loopback test URL, run `go test ./...`, and force-remove the container on every exit. Invoke this script from both `.github/workflows/ci.yml` and `.gitverse/workflows/deploy-production.yaml`; retain `go vet` and `go build` as separate checks.
5. Update T-040 progress to distinguish new real integration coverage from unclosed T-040 work; run full native tests, contract/traceability verifiers, image pin verifier, and inspect sizes and status.

## Exclusions

No production database connection, production deploy, schema migration, DM idempotency change, broad repository refactor, or physical Windows/macOS POC is part of this packet.
