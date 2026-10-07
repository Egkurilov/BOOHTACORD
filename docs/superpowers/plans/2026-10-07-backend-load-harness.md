# Backend load harness implementation plan

> **For agentic workers:** Execute inline in the assigned isolated worktree. The user has already selected parallel agent implementation.

**Goal:** Execute bounded one-guild API/WebSocket load against an owned disposable deployment, report measurements without asserting untested hardware capacity.

**Architecture:** A Python controller reuses the existing labelled disposable PostgreSQL/LiveKit/API/TLS fixture, provisions synthetic accounts and runs an authenticated loopback guard. A Go driver validates the guard before login, exercises existing contracts, samples resource/metric snapshots, stops on limits and writes aggregate evidence. Media stays on the existing SDK/SFU fixture path.

**Tech Stack:** Go 1.26, coder/websocket, Python standard library, existing project Docker QA fixture.

## Operating brief

Route `split_first / large / structure_no_rg`; selected leaves: `validate_target`, `connect_realtime`, `exercise_actor`, `observe_resources`, `record_results`, `run_profile`, `tools/load/{provision,guard,controller}`. Preserve backend API/ACL/session/media behavior: no application runtime edits. Source target 100/hard 120 lines, leaves target 8/hard 16 production files/tests. Native checks: focused Go wire tests; focused Python tests; `go vet`; contracts discovery. Stop when executable driver and controller, protocol/safety tests, docs and evidence exist; physical 100-user/capture/capacity gates remain NOT_RUN.

### Task 1: Safe target and result recording

- [x] Create tests rejecting production, foreign dataset/nonce/origin, redirects, stale/resource snapshots and missing inventory.
- [x] Implement `validate_target` manifest and loopback-only transport, `observe_resources` safety samples and `record_results` bounded route percentiles/error/status/phase summaries.
- [x] Run `go test ./internal/load/validate_target ./internal/load/observe_resources ./internal/load/record_results` from backend; failures first, then PASS.

### Task 2: Real wire actor operations

- [x] Create TLS HTTP + coder/WebSocket fixture tests for login, session identity, ready, fanout, replay/resync, read cursor, leases/credentials/release, ACL, upload/download and logout revocation.
- [x] Implement protocol requests without recording bodies, credentials, IDs or raw error text. Message IDs remain transient deduplication keys only.
- [x] Run `go test ./internal/load/...`; include wrong-cookie owner, missing fanout, corrupt download, wrong-Origin and revoked-session failures.

### Task 3: Owned deployment and bounded stages

- [x] Test guard rejects unauthenticated controls, foreign containers/database/volume, invalid fault families and stale snapshots; restore injected faults in finally.
- [x] Implement controller under `tools/load/controller`, provision under `tools/load/provision`, guard under `tools/load/guard`; existing fixture owns all resources.
- [x] Implement warmup/ramp/steady/spike/recovery/saturation-stop actor scheduling, maximum 100 logical leases and 20 per room, automatic cancellation, bounded upload budgets and cleanup.
- [x] Run `python -m unittest tools.load.guard.test_guard tools.load.provision.test_provision`; run local real-wire Go fixture without Docker.

### Task 4: Evidence and handoff

- [x] Document exact runnable commands, resource stop limits, normal/reconnect/upload/fault profiles and existing separate media fixture commands.
- [x] Record source/protocol results PASS and target hardware/capacity NOT_RUN in `evidence/capacity/issue-8-backend-load-harness-2026-10-07.json`.
- [x] Inspect status/file lengths, stage exact paths, commit, push and create PR referencing #8 without closing its physical acceptance gate.

Actual first Linux API smoke: CI37677120349, job112983443029, 1141 Go tests without skips; 652 requests, 182 fanout samples, p95 5.994291 ms, six phases without errors, owner cleanup PASS. Extended profiles rerun on latest revision before merge.
