# Foundation and Media Gates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish the product contracts, local runnable skeleton, and evidence gates required before feature development of the self-hosted one-guild voice platform.

**Architecture:** The browser Vue client calls a Go modular monolith through HTTPS and a typed WebSocket. The API owns identity, ACL and logical media admission; LiveKit owns RTP/RTCP and media tracks. PostgreSQL and attachment storage use persistent local volumes, while reverse proxy and optional TURN remain isolated infrastructure services.

**Tech Stack:** Vue 3, TypeScript, Vite, Pinia, LiveKit Client SDK, Go, PostgreSQL, LiveKit, Docker Compose, GitHub Actions.

---

## File map

- `AGENTS.md` — project-local operating and safety rules.
- `START_AGENT.md` — bounded bootstrap packet and stop conditions.
- `contracts/openapi.yaml` — REST surface and shared error envelope.
- `contracts/realtime.schema.json` — server-to-client WebSocket event envelope.
- `backlog/tasks.yaml` — machine-readable task graph with requirements and gates.
- `docs/ARCHITECTURE_AND_DATA.md` — components, state, storage and ACL rules.
- `docs/API_AND_REALTIME.md` — contract semantics and idempotency/replay rules.
- `docs/UI_SPEC.md` — mandatory desktop components and state matrix.
- `docs/MEDIA_PROTOTYPE.md` — POC-01/02/03 test protocol and evidence format.
- `docs/ACCEPTANCE.md` — measurable product and release gates.
- `docs/RESEARCH_NOTES.md` — facts still needing confirmation, kept distinct from requirements.
- `templates/evidence.json` — schema-shaped evidence record template.

### Task 1: Create the authoritative specification packet

**Files:**
- Create: `AGENTS.md`, `START_AGENT.md`, `backlog/tasks.yaml`
- Create: `docs/ARCHITECTURE_AND_DATA.md`, `docs/API_AND_REALTIME.md`, `docs/UI_SPEC.md`, `docs/MEDIA_PROTOTYPE.md`, `docs/ACCEPTANCE.md`, `docs/RESEARCH_NOTES.md`
- Create: `templates/evidence.json`

- [ ] **Step 1: Write failing traceability check.** Add a small PowerShell check that extracts all `REQ-*` identifiers from `C:\Users\egkur\Downloads\TZ_Voice_Platform_v1.0.md` and fails if `backlog/tasks.yaml` has no matching requirement reference.

  Run: `powershell -NoProfile -File scripts/verify-spec-traceability.ps1`

  Expected: fail before `backlog/tasks.yaml` exists.

- [ ] **Step 2: Add the packet.** Define source precedence, one-guild boundary, component ownership, state transitions, UI state matrix, POC methodology, metric thresholds, evidence shape and a requirement-to-task graph. State unknowns as unconfirmed rather than selecting a value.

- [ ] **Step 3: Verify traceability.**

  Run: `powershell -NoProfile -File scripts/verify-spec-traceability.ps1`

  Expected: `Traceability OK` with every top-level `REQ-*` represented in the backlog.

### Task 2: Establish protocol contracts

**Files:**
- Create: `contracts/openapi.yaml`
- Create: `contracts/realtime.schema.json`
- Modify: `docs/API_AND_REALTIME.md`
- Test: `scripts/verify-contracts.ps1`

- [ ] **Step 1: Write failing contract check.** Verify that OpenAPI is valid JSON/YAML, exposes versioned `/api/v1` paths, and that the WebSocket schema accepts only documented event kinds.

  Run: `powershell -NoProfile -File scripts/verify-contracts.ps1`

  Expected: fail while contract files do not exist.

- [ ] **Step 2: Define minimal foundation contracts.** Add `GET /api/v1/health`, shared `Error` with stable codes including `INSUFFICIENT_STORAGE`, and a WebSocket envelope with `event_id`, `kind`, `occurred_at`, `payload`. Document that contracts expand feature-by-feature only with matching tests.

- [ ] **Step 3: Verify contract syntax.**

  Run: `powershell -NoProfile -File scripts/verify-contracts.ps1`

  Expected: `Contracts OK`.

### Task 3: Bootstrap isolated local runtime

**Files:**
- Create: `backend/go.mod`, `backend/cmd/api/main.go`, `backend/internal/health/handler.go`, `backend/internal/health/handler_test.go`
- Create: `frontend/package.json`, `frontend/vite.config.ts`, `frontend/src/main.ts`, `frontend/src/App.vue`
- Create: `compose.yaml`, `.env.example`, `.gitignore`
- Test: `backend/internal/health/handler_test.go`

- [ ] **Step 1: Write a failing Go HTTP test.** The test must call `health.NewHandler` through `httptest` and expect status `200` with body `{"status":"ok"}`.

- [ ] **Step 2: Run the targeted test.**

  Run: `go test ./internal/health -run TestHandler -count=1`

  Expected: fail because the handler package is absent.

- [ ] **Step 3: Implement a minimal API process.** Add the handler and wire `GET /api/v1/health` to an HTTP server that binds `API_ADDR`, defaulting to `:8080`; no business endpoint may bypass middleware later.

- [ ] **Step 4: Run unit test and compose config validation.**

  Run: `go test ./...` from `backend`; `docker compose -f compose.yaml config`

  Expected: Go tests pass and Compose renders a PostgreSQL, API, LiveKit and proxy topology with named persistent volumes.

### Task 4: Prepare media evidence gates

**Files:**
- Modify: `docs/MEDIA_PROTOTYPE.md`, `docs/ACCEPTANCE.md`, `templates/evidence.json`
- Create: `evidence/README.md`

- [ ] **Step 1: Add unambiguous POC run sheets.** Each sheet must name the two physical machines, OS and Chrome versions, audio devices, game, capture source, observer, timestamps, expected signal path, metrics and pass/fail conditions.

- [ ] **Step 2: Add status vocabulary.** Evidence records must permit only `PASS`, `FAIL`, `BLOCKED`, and `NOT_RUN`; `PASS` requires artifact paths and human observer identity, while `BLOCKED` requires the unresolved environmental condition.

- [ ] **Step 3: Validate JSON template.**

  Run: `Get-Content -Raw templates/evidence.json | ConvertFrom-Json | Out-Null`

  Expected: exit code `0`.

### Task 5: Review the foundation packet

**Files:**
- Modify: `TODO.md`
- Test: `scripts/verify-spec-traceability.ps1`, `scripts/verify-contracts.ps1`

- [ ] **Step 1: Check the task graph.** Confirm that all 23 explicit top-level `REQ-*` identifiers and every POC/gate have a backlog task and acceptance evidence.

- [ ] **Step 2: Check exclusions.** Confirm contracts and Compose omit multi-guild state, backups, Redis, custom SFU, camera, recordings, mobile services and global accounts.

- [ ] **Step 3: Update checklist.** Mark `T-001` complete only when both scripts pass; leave POC tasks open until hardware evidence exists.

- [ ] **Step 4: Commit the focused packet.**

  Run: `git add AGENTS.md START_AGENT.md TODO.md backlog/tasks.yaml contracts docs templates scripts evidence .gitignore .env.example && git commit -m "docs: add platform foundation specification"`

  Expected: one reviewable documentation commit, without credentials or generated media.
