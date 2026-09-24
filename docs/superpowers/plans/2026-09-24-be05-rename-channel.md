# BE-05 Rename Channel Implementation Plan

> **For agentic workers:** Implement this plan task by task in the current BE-05 agent. The user has already authorized implementation.

**Goal:** Let an administrator rename an active TEXT or VOICE channel with an expected topology revision, without changing its kind.

**Architecture:** A new `rename_channel` leaf validates input, handles the HTTP request, and executes one PostgreSQL transaction under the existing topology advisory lock. The transaction changes `channels.name`, advances `channel_topology_state.revision`, and records `CHANNEL_RENAMED` in `audit_events`. `channel_routes.go` only wires authentication, administrator authorization, and the handler.

**Tech Stack:** Go 1.26, `net/http`, pgx, PostgreSQL.

---

### Task 1: Validate the rename command

**Files:** Create `backend/internal/channel/rename_channel/service_test.go`, `backend/internal/channel/rename_channel/service.go`.

- [x] Write a service test that passes `ActorID`, `ChannelID`, `Name`, and `ExpectedRevision` to a fake store and checks the returned `{id,name,revision}`.
- [x] Write table tests that reject an empty actor/channel, revision below 1, invalid UTF-8, and names with 0 or 81 Unicode code points before calling the store. Use `categoryname.Validate` for the existing 1–80 rule.
- [x] Run `go test ./internal/channel/rename_channel` from `backend`; expect a compile failure before adding the service.
- [x] Implement `Input`, `Result`, `Store`, `Service.Rename`, `ErrInvalidInput`, and `ErrRevisionConflict` with the same contract as `rename_category`.
- [x] Rerun `go test ./internal/channel/rename_channel`; expect PASS.

### Task 2: Guard the PostgreSQL mutation

**Files:** Create `backend/internal/channel/rename_channel/postgres/repository_test.go`, `repository.go`, `pool_database.go`.

- [x] Write a fake-transaction test that checks the topology lock is acquired, the SQL updates only `channels.name`/`updated_at`, the channel must have `archived_at IS NULL`, the expected revision is checked, audit metadata contains the channel ID, and commit follows a successful scan.
- [x] Write a `pgx.ErrNoRows` test for missing/archived channel or stale revision; expect `ErrRevisionConflict` and rollback. Test lock/query/commit errors preserve failure and rollback.
- [x] Run `go test ./internal/channel/rename_channel/postgres`; expect a compile failure before implementation.
- [x] Implement `Repository.Rename` with one transaction, `pg_advisory_xact_lock(441903817)`, guarded UPDATE, revision increment, and `CHANNEL_RENAMED` audit insertion. Return `{id,name,revision}` only after commit.
- [x] Rerun `go test ./internal/channel/rename_channel/postgres`; expect PASS.

### Task 3: Expose the administrator API

**Files:** Create `backend/internal/channel/rename_channel/api/http_handler_test.go`, `http_handler.go`; modify `backend/cmd/api/channel_routes.go`.

- [x] Write handler tests for `PATCH /api/v1/admin/channels/{channelID}` with `{\"name\":\"Игры\",\"expected_revision\":2}`. Check the principal ID reaches the service, response has `{\"id\":...,\"name\":...,\"revision\":3}`, malformed input and unknown `kind` return 400, conflict returns 409, and a non-administrator wrapped with `RequireAdministrator` gets 403 without calling the service.
- [x] Run `go test ./internal/channel/rename_channel/api`; expect a compile failure before implementation.
- [x] Implement a strict 8 KiB JSON handler that maps invalid input to 400, revision conflict to 409, and internal errors to 500. Register its handler through `Require` and `RequireAdministrator` at the exact PATCH route.
- [x] Run `go test ./internal/channel/rename_channel/... ./cmd/api`; expect PASS. Run `go vet ./internal/channel/rename_channel/... ./cmd/api`; expect PASS.

### Task 4: Handoff and contract verification

**Files:** The root agent owns `contracts/openapi.yaml`, `contracts/mobile-client-contract.md`, and API documentation.

- [x] Tell the root agent the final PATCH request/response and tests so it can update shared contracts without edit collision.
- [ ] After shared contract edits, run `scripts/verify-contracts.ps1` from the repository root; expect PASS.
- [x] Inspect `git status --short` and changed file sizes. Do not stage, commit, or push in this shared checkout.
