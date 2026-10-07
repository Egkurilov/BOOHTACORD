# On-call integration map Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. These child skills are unavailable here; the owner already requested parallel agents and this isolated worker executes the native pipeline.

**Goal:** Give an operator one source-checked integration table without exposing private dependencies through public health.

**Architecture:** Preserve the existing administrator-only readiness view and runtime. Add a Russian operator table with exact source links, recovery boundaries and evidence limits. A bounded Python leaf verifies complete table coverage and rejects timeout/readiness source drift through the existing tools regression runner.

**Tech Stack:** Markdown, Python unittest, Go httptest, existing project CI contracts runner.

---

## Operating brief

- Route: `split_first`, leaf `tools/verify/oncall_map`, T-002/T-003 depend on T-001.
- Doctrine: one guild, private management/storage, server ACL; no media proxy or new TURN, secrets or backups.
- Baseline: public health returns only status ok; readiness requires session plus ADMINISTRATOR, three serial 400 ms probes, 200 ready or 503 degraded, no-store.
- Ratchet: new executable files <=120 lines; one checker trigger; <=8 production/direct test files.
- Exact sources: API runtime, database pool, readiness, RoomService snapshot/removal and durable dispatcher, Caddy, LiveKit config, telemetry exporter/relay, attachment writer, realtime handler and browser reconnect policies.
- Stop: seven table rows/source anchors verified, readiness privacy tests and links/topology/native contracts pass; evidence records source proof separately from production outage/device gates.
- Unresolved: production failure injection and POC-03 remain unproven; do not close #7 or release/deploy.

### Task 1: Preserve readiness authorization and health behavior

**Files:** Create `backend/internal/observability/inspect_readiness/handler_test.go`.

- [x] Write tests using `httptest.NewRequest`, `sessionapi.WithPrincipal` and existing database/SFU/storage stubs. Anonymous =>401, MEMBER/MODERATOR=>403 without probes. ADMINISTRATOR=>200 ready; failing private dependencies=>503 without raw error details. Verify no-store and public health body only status ok under the same failed dependency fixture.
- [x] Run `go test ./internal/observability/inspect_readiness ./internal/health` from backend; expected PASS. This preserves existing behavior; no runtime endpoint or health mutation is required.

```go
request := httptest.NewRequest("GET", "/api/v1/admin/readiness", nil)
request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{Role: "ADMINISTRATOR"}))
response := httptest.NewRecorder()
Handler(service).ServeHTTP(response, request)
if response.Code != 503 || strings.Contains(response.Body.String(), "secret-host") { t.Fatal("unsafe readiness") }
```

### Task 2: Write failing table/timeout drift tests

**Files:** Create `tools/verify/oncall_map/test_check.py`.

- [x] Test missing table, omitted/duplicate flow, incomplete columns, unproven POC claim, missing source anchors and wrong deadline fail. Valid complete real repository table passes; temporary source mutation must fail.
- [x] Run `python -m unittest tools.verify.oncall_map.test_check -v`; expected import failure before checker exists.

```python
errors = validate(root)
self.assertEqual(errors, [])
broken = text.replace("400 ms", "4 s")
self.assertTrue(validate_document(broken))
```

### Task 3: Add one operator table and bounded checker

**Files:** Create `docs/operations/oncall-integrations.md`, `tools/verify/oncall_map/check.py`, `tools/verify/oncall_map/anchors.py`; modify `docs/runbooks/README.md`, `docs/observability/README.md`.

- [x] Table has exactly PostgreSQL, RoomService, LiveKit/TURN, Caddy/admission, OTLP/Tempo, attachments and realtime rows. Every row includes scenarios, boundary/owner, actual timeout/retry, failure/symptoms, signals, readiness, recovery and evidence links.
- [x] Document missing SQL/body/write deadlines, no automatic mutation replay, SDK vs custom retry, collector loss/queue semantics, no public management access, no media-capacity claim, absent TURN, required paired/device/POC proofs.
- [x] Parse the Markdown table, require seven identifiers/eight columns and each source/document/evidence link, and compare explicit deadline anchors in source with their documented phrases. No external network call or secret read.

```python
def validate(root):
    text = (root / DOCUMENT).read_text(encoding="utf-8")
    errors = validate_document(text)
    for path, anchor in ANCHORS:
        if anchor not in (root / path).read_text(encoding="utf-8"):
            errors.append("source drift: " + path)
    return errors
```

- [x] Existing `tools.verify.python_tests.run` discovers this checker test automatically; avoid workflow edits and extra distributions.
- [x] Run focused tests plus `python -m tools.verify.oncall_map.check`, `python -m tools.verify.links.check`, `python -m tools.verify.writer_topology.check`, `python -m tools.ci.native.contracts`; expected all PASS.

### Task 4: Evidence and reviewable delivery

**Files:** Create `evidence/observability/issue-7-oncall-integrations-2026-10-07.json`.

- [x] Record executed source/native checks PASS and production faults/POC media replay NOT_RUN/BLOCKED; no raw config/credentials or acceptance closure.
- [x] Inspect `git status --short` and exact changed sizes; stage exact paths, commit, push `codex/issue-7-oncall-integrations`, create PR with structured body referencing #7 without auto-closing keyword, attach PR.
- [x] Report exact coverage, head SHA, test counts and limitations to integrator.
