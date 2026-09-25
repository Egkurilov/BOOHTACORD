# QA-11 GHCR CI Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the approved `main` → GHCR pipeline reject skipped PostgreSQL tests and publish SBOM plus explicit max-level provenance with digest-qualified image references.

**Architecture:** Keep the existing GitHub `main`/GHCR workflow and its test → publish → deploy dependencies. Move the three independent test jobs into same-revision reusable workflows so every edited file stays under the 120-line ratchet. Reuse the Go JSON no-skip validator from GitVerse CI, then make Buildx attestations explicit on both pushed images. This packet does not change GitVerse production or claim a trusted GitHub run.

**Tech Stack:** GitHub Actions YAML, Go test JSON, Python 3, Docker Buildx, GHCR.

---

### Task 1: Prove the existing Go gate rejects skipped integration tests

**Files:**
- Read: `scripts/verify-go-test-events.py`
- Create: `.github/workflows/ci-contracts.yml`, `.github/workflows/ci-backend.yml`, `.github/workflows/ci-frontend.yml`
- Modify: `.github/workflows/ci.yml` (three job bindings)

- [x] **Step 1: Run the negative gate fixture.**

```bash
printf '%s\n' '{"Action":"skip","Package":"voice-platform/backend/internal/chat/create_text_message/postgres","Test":"TestRequiresPostgres"}' > /tmp/qa11-skip-events.json
python3 scripts/verify-go-test-events.py /tmp/qa11-skip-events.json
```

Expected: exit 1 with one skipped test.

- [x] **Step 2: Prove the reusable-workflow structure is initially absent.** A local YAML check must fail while the three child files do not exist and the main workflow still owns executable test jobs.
- [x] **Step 3: Move each existing test job into its child workflow.** Each child starts with `on: { workflow_call: }`, `permissions: { contents: read }`, and the exact original job under `jobs`. In the main workflow replace each moved job body with `uses: ./.github/workflows/ci-<name>.yml`; preserve `publish.needs: [contracts, backend, frontend]` and `deploy.needs: publish`.
- [x] **Step 4: Wire the same gate into `.github/workflows/ci-backend.yml`.** Replace `go test ./...` with:

```bash
set -euo pipefail
test_events="$(mktemp "${RUNNER_TEMP:-/tmp}/backend-test-events.XXXXXX")"
test_status=0
go test -json -count=1 ./... > "$test_events" || test_status=$?
python3 ../scripts/verify-go-test-events.py "$test_events"
test "$test_status" -eq 0
go vet ./...
go build -o /tmp/voice-platform-api ./cmd/api
```

- [x] **Step 5: Parse the workflows and check the exact backend step.**

```bash
python3 - <<'PY'
import yaml
workflow = yaml.safe_load(open('.github/workflows/ci-backend.yml', encoding='utf-8'))
script = workflow['jobs']['backend']['steps'][-1]['run']
assert 'go test -json -count=1 ./...' in script
assert 'verify-go-test-events.py' in script
assert 'go vet ./...' in script
PY
```

Expected: exit 0.

### Task 2: Make image attestations explicit

**Files:**
- Modify: `.github/workflows/ci.yml` (two `docker/build-push-action@v6` steps)

- [x] **Step 1: Add `provenance: mode=max` next to existing `sbom: true` for both pushed images.** Keep `push: true` and the existing digest outputs; Docker's local image exporter does not retain these attestations.
- [x] **Step 2: Validate both image steps and the deploy dependency.**

```bash
python3 - <<'PY'
import yaml
workflow = yaml.safe_load(open('.github/workflows/ci.yml', encoding='utf-8'))
publish = workflow['jobs']['publish']
steps = [step for step in publish['steps'] if step.get('uses') == 'docker/build-push-action@v6']
assert len(steps) == 2
for step in steps:
    inputs = step['with']
    assert inputs['push'] is True and inputs['sbom'] is True
    assert inputs['provenance'] == 'mode=max'
assert workflow['jobs']['deploy']['needs'] == 'publish'
PY
```

Expected: exit 0.

### Task 3: Record the remaining external acceptance boundary

**Files:**
- Create: `evidence/release/qa11-ghcr-ci-hardening-2026-09-25-001.json`
- Modify: `backlog/VERIFICATION_TODO.md`

- [x] **Step 1: Record `PARTIAL` evidence:** the source and local structural checks pass; no GitHub `main` run or published digest/attestation was observed. Preserve the separate GitVerse/master versus approved main/GHCR decision in QA-11.
- [x] **Step 2: Run `scripts/verify-spec-traceability.ps1`, `git diff --check`, and review exact staged files and sizes.**
- [x] **Step 3: Commit only the workflow, QA-11 backlog note, evidence and this plan; push the working branch.**

QA-11 closes only after the delivery decision is recorded in an accepted ADR and the selected trusted pipeline proves immutable image references, SBOM/provenance and deployment checks. The production attachment filesystem failure in QA-08 prevents a new production rollout now.
