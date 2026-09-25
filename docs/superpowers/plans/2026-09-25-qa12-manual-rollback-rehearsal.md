# QA-12 Manual Rollback Rehearsal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Add a trusted, manual, fail-closed GitVerse entrypoint for a compatible two-way image rehearsal without dispatching it.

**Architecture:** A production-concurrency workflow accepts exact current and previous 40-character revisions, checks out master, and invokes the current deployed release over pinned SSH. A remote preflight verifies running images, both local image tags, matching backend/Compose source, release directories, and named volumes before a separate orchestrator switches to the previous tags, audits, then restores and audits current tags. Browser observations and content checks remain an external QA-12 acceptance requirement.

**Tech Stack:** GitVerse workflow_dispatch, Bash, Docker Compose, existing deploy-images.sh and audit-attachment-volume.sh, fake Docker tests.

---

### Task 1: Read-only compatibility preflight

**Files:** Create `scripts/qa12_rollback/preflight.sh`; test `scripts/qa12_rollback/preflight.test.sh`.

- [x] Write a fake-Docker test that creates two release trees, four pinned local images, exact running current API/web tags and four volume identities. Assert success, then assert failures for current drift, missing previous tag, backend/Compose mismatch, and missing volume.
- [x] Run `bash scripts/qa12_rollback/preflight.test.sh`; expect failure while `preflight.sh` is absent.
- [x] Implement `preflight.sh CURRENT_SHA PREVIOUS_SHA [RELEASE_ROOT]` with strict SHA validation, exact `/opt/voice-platform-releases/<sha>` directories, `diff -qr` backend, `cmp` Compose/Caddyfile, `.env` and running-image checks, image IDs, and volume identity output. Do not print `.env` or perform mutations.
- [x] Rerun the focused test; expect PASS.

### Task 2: Bounded two-way rehearsal

**Files:** Create `scripts/qa12_rollback/rehearse.sh`; test `scripts/qa12_rollback/rehearse.test.sh`.

- [x] Write a test with fake `deploy-images.sh` and audit scripts that records previous→current ordering, both audit arguments and unchanged volume identities; inject a previous-audit failure and require attempted current restore.
- [x] Run `bash scripts/qa12_rollback/rehearse.test.sh`; expect failure while `rehearse.sh` is absent.
- [x] Implement `rehearse.sh CURRENT_SHA PREVIOUS_SHA [RELEASE_ROOT]`: call preflight, record volume identities, audit current, switch through the existing deploy script, audit previous, allow a bounded observer window, restore current and audit. EXIT trap attempts current restore after any failure following the first switch. No down migration, backup or volume deletion.
- [x] Rerun focused and existing `deploy-images-rollback.test.sh`; expect PASS.

### Task 3: Trusted manual CI binding and evidence

**Files:** Create `.gitverse/workflows/rehearse-compatible-rollback.yaml`; update `scripts/verify-release-guards.sh`; create `evidence/release/qa12-manual-entrypoint-2026-09-25-001.json`.

- [x] Add a workflow-dispatch contract test checking required exact inputs, master-only gate, production concurrency group, pinned SSH, and invocation of the deployed current release script; run it red before creating the workflow.
- [x] Add the workflow with `current_sha`, `previous_sha`, and explicit observer/window confirmation. Pass inputs through environment variables; validate syntax before shell interpolation; do not dispatch from this packet.
- [x] Run focused tests, release guards, YAML parser/actionlint, shellcheck and `git diff --check`; record source-level PASS and live rehearsal NOT_RUN in evidence.

### Self-review

- [x] Verify source requirements: exact current/previous tags, same backend/Compose, no down migration/backup/volume removal, current restore on failure, volume identities, audit before/after, manual master-only workflow.
- [x] Keep QA-12 open until two independent real browser sessions, live schema compatibility, real named-volume content checks and successful two-way run are evidenced.
