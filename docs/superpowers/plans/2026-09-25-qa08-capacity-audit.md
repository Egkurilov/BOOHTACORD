# QA-08 Read-Only Capacity Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Obtain a current, reproducible measurement of the production attachment volume and in-flight upload reservations without changing production state.

**Architecture:** A manually dispatched GitVerse workflow on `master` uses the existing pinned deploy SSH identity. Its remote script reads the exact Docker volume, filesystem, API container and private metrics endpoint, emits only bounded numeric/health fields, and fails closed if any measurement is unavailable. No build, migration, Docker cleanup or service restart runs in this workflow.

**Tech Stack:** Bash, Docker CLI, `df`, `findmnt`, `curl`, GitVerse Actions.

---

### Task 1: Define read-only measurement behavior

**Files:**
- Create: `scripts/audit-attachment-volume.test.sh`
- Create: `scripts/audit-attachment-volume.sh`

- [x] Add shell stubs for exact volume, filesystem, running API and private metrics; assert output and rejection of absent/malformed readings.
- [x] Run the test red before writing the audit script.
- [x] Implement the bounded remote audit without logging secrets, message text, DM IDs or attachment names.
- [x] Run focused shell test, `bash -n` and `shellcheck`.

### Task 2: Add a master-only manual CI entrypoint

**Files:**
- Create: `.gitverse/workflows/audit-attachment-volume.yaml`
- Modify: `scripts/verify-release-guards.sh`

- [x] Restrict execution to `workflow_dispatch` on `master`; use the existing pinned host-key setup and batch SSH.
- [x] Execute only `bash scripts/audit-attachment-volume.sh` remotely and preserve its exit status.
- [x] Add the focused shell test to native release guards.
- [x] Run the complete native release guards.

### Task 3: Capture production evidence

**Files:**
- Create: `evidence/capacity/qa08-attachment-volume-2026-09-25-008.json` after current read-only CI audit; prior trusted deploy guard is recorded in `007`.
- Modify: `TODO.md`, `backlog/VERIFICATION_TODO.md`, `DONE.md`, requirement matrix only if the measurement changes their verified state.

- [ ] Commit and publish the workflow through the normal branch/master path only after native checks; do not bypass the deployment disk guard.
- [ ] Manually dispatch the read-only workflow and inspect trusted logs for exact bytes, reservation gauge, image revision and health.
- [ ] Compare pre/post deploy measurements with the current reading; mark QA-08 PASS only if the scoped acceptance criteria are proven, otherwise record PARTIAL/BLOCKED with the exact gap.
