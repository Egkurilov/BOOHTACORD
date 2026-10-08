# Search date range implementation plan

> For agentic workers: execute this bounded search packet inline, with native behavior checks.

**Goal:** Finish IMP-16 date filtering within the existing authorized unified message search.

**Architecture:** Preserve author/attachment filtering and descending mixed-source cursor. API accepts explicit RFC3339 instants; browser maps local calendar dates to midnight boundaries using calendar arithmetic, never a fixed 24-hour duration. No new search system or ACL exemption.

**Tech Stack:** Go, PostgreSQL/pgx, Vue 3/Pinia, TypeScript, Vitest.

Operating brief: split_first; routes search_messages service/api/postgres and Web search/filters; hard 120 source lines, max 16 production files per leaf; exact files below; stop at committed source with checks/evidence and explicit unrun runtime QA.

## Backend and contract

- [x] Add date-range service tests: offset normalization, malformed/no-offset/reversed/equal boundaries rejected before store, bounds retained on cursor continuation.
- [x] Implement `Input.CreatedFrom/CreatedBefore` strings, parsed `Request` time pointers, and strict RFC3339 validation in `search_messages/date_range.go`.
- [x] Extend `api/filters.go` to reject duplicate/empty bound parameters, wire them through `api/http_handler.go`, and add handler date tests.
- [x] Append `$11/$12` timestamp arguments in `postgres/repository.go`; apply `created_at >= $11` and `< $12` in both SQL arms in `postgres/statements.go`, preserving `$7/$8/$9` cursor and ACL/deletion predicates.
- [x] Add PostgreSQL boundary/cursor/privacy tests and query-plan checks using existing disposable-schema fixtures and partial GIN indexes.
- [x] Document inclusive/exclusive semantics and local-day conversion in ADR-019 and OpenAPI.

## Browser

- [x] Add failing `filters/date_range.spec.ts`: invalid dates, reverse interval, UTC and America/New_York spring/fall transitions (23/25-hour days), single-ended intervals.
- [x] Implement local `new Date(year, month-1, day)` validation; exclusive end uses `new Date(year, month-1, day+1)` and `.toISOString()`.
- [x] Retain start/end dates in Pinia `filters/state.ts` and verify reopen/reset/logout through native cleanup tests.
- [x] Add accessible date controls to `filters/SearchFilters.vue`; update `SearchPanel.vue` reset/validation/request wiring while keeping source <=120 lines.
- [x] Extend `search_messages_client.ts` and tests to preserve RFC3339 parameters with cursor pages and existing filters.

## Verification and delivery

- [x] Run `go test ./internal/chat/search_messages/...` and `go vet ./internal/chat/search_messages/...` in backend. Record any DB skips honestly; use disposable local PostgreSQL if available.
- [x] Run focused Vitest search and logout tests; then full Web suite and `npm run build` once focused checks pass.
- [x] Run `tools/verify/contracts/verify.ps1` and OpenAPI parity validator; record integration evidence without real messages/IDs.
- [x] Inspect `git status --short`, changed line counts, and `git diff --check`; stage exact source/test/docs/evidence paths and commit locally. No push or issue mutation in this delegated packet.

Observed: all relevant search PostgreSQL scenarios PASS (21 tests, no skips across 3 packages); four real Chromium component checks PASS; full Web 1,355 tests PASS plus 13 focused filter tests after added edges; contract 19/parity 90 and traceability 39 PASS. Legacy unrelated IMP-17 corpus timed out 10 min on remote sequential inserts; record is explicit. Full production QA-04/visual acceptance remains separate.
