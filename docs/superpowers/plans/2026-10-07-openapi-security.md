# OpenAPI security and backend parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Make the public contract show the actual cookie, Origin, parameter and response boundaries, and reject drift in CI.

**Architecture:** Keep application behavior unchanged. Read Go route registrations through the native AST and inspect exact handler request edges. Verify the JSON-formatted OpenAPI in a separate leaf called by the existing contract gate, and provide a pinned local Swagger viewer.

**Tech Stack:** Go standard-library AST, Python 3.12 unittest, PowerShell, OpenAPI 3.1, Swagger UI.

---

Operating brief: route=tools/verify/openapi_parity; class=split_first; doctrine=AGENTS.md and project SKILL.md; source boundary=runtime/routes.go and its imported route and handler edges; ratchets=100 target/120 hard per implementation file, 8 target/16 hard files; baseline=86 contract operations versus current registrations, anonymous logout and optional session, exact Origin on mutations, empty relay failures; stop=focused mutation tests and native contract gate pass, reviewable PR; unresolved=live Swagger visual acceptance.

### Task 1: Native route evidence and negative tests

Files: create `tools/verify/openapi_parity/{source.go,bindings.go,extract.go,source.py,validate.py,test_parity.py}`.

- [x] Parse Go registrations starting at `backend/internal/app/runtime` and follow exact imported route edges, including delegated media registrations.
- [x] Resolve handler variables and topology handler fields before checking required session wrappers.
- [x] Add tests that remove/add routes, change security to anonymous, remove or invent path/query/header parameters, and replace error body/header definitions. Each must raise a focused parity error.
- [x] Run `python -m unittest tools.verify.openapi_parity.test_parity`; confirm the current contract fails the actual-route baseline.

### Task 2: Accurate public security and responses

Files: modify `contracts/openapi.yaml`; create audited request/response expectations in `tools/verify/openapi_parity/policy.json`.

- [x] Add `vp_session` cookie scheme and explicit operation security; exempt public metadata, registration/login/reset/logout and optional session according to handlers.
- [x] Add exact Origin mutation parameters, optional realtime same-host Origin semantics, generated response X-Request-ID and success Set-Cookie where emitted.
- [x] Add screen-profile request/response schemas and operation from its handler.
- [x] Audit request query/header edges and actual response statuses. Preserve empty relay and middleware 500 bodies and the client-update string error envelope; require Error only for real standard JSON errors.
- [x] Document excluded metrics, LiveKit webhook and signal admission hook with their separate network and authentication boundaries.
- [x] Run the focused tests and parity CLI until the full current route set passes.

### Task 3: Contract gate and local Swagger viewing

Files: modify `tools/verify/contracts/verify-contracts.ps1`; create `tools/contracts/swagger_view/{serve.py,index.html,README.md}` and `evidence/contracts/issue-4-openapi-security.json`.

- [x] Register the parity unittest and CLI in the existing verifier used by CI contracts.
- [x] Serve the exact contract and a pinned Swagger UI on loopback with documented browser cookie/Origin constraints.
- [x] Run `tools/verify/contracts/verify-contracts.ps1` and focused viewer checks; record PASS or explicit NOT_RUN physical acceptance.
- [x] Inspect `git status --short`, diff and changed implementation line counts, stage only exact files, commit, push and open a PR targeting master that references #4 without closing it.
