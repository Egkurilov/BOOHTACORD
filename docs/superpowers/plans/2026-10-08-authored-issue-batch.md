# Authored Issue Batch Implementation Plan

> **For agentic workers:** Use the assigned subagent workstream for bounded issue groups. Keep changes on the current `codex/next20-authored-issues-2026-10-08` branch; do not stage, commit, or push from a workstream.

**Goal:** Resolve remaining source-code gaps among the next 20 open issues authored by Egkurilov and record precise outstanding acceptance for implementations that already exist.

**Architecture:** Scope is #223 and #176–#158, selected from the author's open P1 issues plus the adjacent P2 preview delivery issue. Work is split by independent capability: release-catalog promotion, preview/foundation, client capture/viewers, and final screen-share rollout/acceptance. Existing implementation is preserved; physical device, real SFU, production Grafana, and production delivery claims require their own evidence.

**Tech Stack:** GitHub Actions, Python release tooling, Node.js publisher tests, Go API, Vue/Vitest/Playwright, Flutter/Dart, JSON evidence and Grafana provisioning.

---

### Task 1: Confirm issue scope and current implementation

**Issues:** #223, #176, #175, #174, #173, #172, #171, #170, #169, #168, #167, #166, #165, #164, #163, #162, #161, #160, #159, #158.

**Files:**
- Review: `backlog/tasks.yaml`, exact issue descriptions/comments, and the capability paths listed below.
- Evidence: existing issue-specific evidence records and current master SHA.

- [x] Verify all 20 remain open and authored by `Egkurilov`.
- [x] Check existing source, native tests, and issue comments before editing.
- [x] Keep every issue open while mandatory runtime or physical acceptance is `NOT_RUN`.
- [x] Reuse an existing adequate acceptance comment; update only stale issue evidence and never post duplicate test instructions.

### Task 2: Complete the Windows release-to-catalog source path (#223)

**Files:**
- Review: `.github/workflows/windows-release.yaml`
- Create: `.github/workflows/promote-windows-client-update.yaml`
- Review/modify: `tools/release/windows/publish.mjs`
- Test: `tools/release/windows/publish.test.mjs`
- Reuse: `tools/release/client_updates/catalog.py`
- Test: `tools/release/client_updates/test_catalog.py`
- Create: `tools/release/client_updates/promote_windows_release.py`
- Test: `tools/release/client_updates/test_windows_promotion.py`
- Test: `tools/release/client_updates/test_windows_promotion_security.py`
- Input contract: `tools/release/native_artifact/manifest.py`
- Runtime catalog: `deploy/client-updates/catalog.json`

- [x] Derive a stable update target from the verified immutable Windows release manifest and checksum-verified archive; verify ZIP inventory/file hashes and release state, and never infer package identity from a tag alone.
- [x] Use the catalog's expected-revision compare-and-swap and release-order protections for a single Windows/direct/stable/x64 selector.
- [x] Route promotion through a manual `workflow_dispatch` action that opens a review PR; do not bypass master protections or silently promote any tag.
- [x] Run catalog tests and validation before publishing a candidate. Keep endpoint readback and installed-old-client acceptance as separate gates.
- [x] Update the existing #223 comment with the current master/catalog revision, completed automated checks, and exact required production/Windows evidence.

**Checks:** `python -m pytest -q tools/release/client_updates/test_catalog.py tools/release/client_updates/test_windows_promotion.py tools/release/client_updates/test_windows_promotion_security.py`; `python -m tools.release.client_updates.catalog validate --path deploy/client-updates/catalog.json`; `node --test tools/release/windows/publish.test.mjs`; contract checks for the release/catalog workflow.

### Task 3: Verify implemented foundation and private preview work (#158–#163)

**Files/routes:**
- `clients/web/tests/screen_profile/`
- `clients/web/src/voice/screen_livekit_diagnostics.ts`
- `clients/web/src/voice/screen_publisher/`
- `clients/web/src/voice/livekit_screen_viewer_adapter.ts`
- `clients/web/src/voice/screen_preview/`
- `clients/flutter/lib/src/services/screen_share_metrics.dart`
- `clients/flutter/lib/src/features/screen/lifecycle/`
- `clients/flutter/lib/src/features/voice/screen_preview/`
- `backend/internal/app/runtime/routes.go`
- `backend/internal/app/media_routes/screen_preview_routes.go`
- `backend/internal/app/media_routes/screen_preview/`
- `tools/verify/paired_screen_acceptance/`
- `evidence/media/issue-173-paired-acceptance-2026-10-07.json`

- [x] Confirm current code and focused test results; no source delta is justified by the audit.
- [x] Keep SFU baseline, per-layer paired SDK data, lifecycle race acceptance, real subscription counts, database/LiveKit ACL/revocation/load checks as `NOT_RUN` until run on the required environment.
- [x] Retain the already-published #158–#163 comments that list exact platform setup, scenarios, sanitized numeric evidence, and `PASS|FAIL|NOT_RUN` requirements.

**Checks:** `npm run test:screen-profile`; focused Web preview/viewer/diagnostics Vitest suite; `go test ./internal/media/screen_preview/... ./internal/app/media_routes/screen_preview`; Flutter checks where the Dart SDK exists.

### Task 4: Verify implemented Web/Flutter capture, codec, adaptation, and network work (#164–#172)

**Files/routes:**
- `clients/web/src/voice/screen_viewer_controller.ts` and adjacent `screen_viewer_*` tests
- `clients/web/src/voice/screen_publisher/codec_policy.ts`
- `clients/web/src/voice/screen_profile/`
- `clients/web/src/voice/screen_profile_metadata/`
- `clients/flutter/lib/src/features/screen/capture/`
- `clients/flutter/lib/src/features/screen/lifecycle/`
- `clients/flutter/lib/src/features/screen/sender_metadata/`
- `tools/verify/livekit_network_config/`
- `deploy/livekit/`
- `clients/web/tests/screen_profile/screen_share_sfu*`

- [x] Confirm the existing code paths and issue comments; source edits are limited to a reproducible uncovered defect.
- [x] Keep Flutter device, codec A/B, long-running SDK/SFU, UDP/TURN, fault-injection, and physical capture results `NOT_RUN` until their required environments are available.
- [x] Preserve the existing comments for #164–#172 that spell out device/browser versions, cycles, network profiles, resource counts, safe artifacts, and acceptance states.

**Checks:** focused Vitest suites plus `npm run build`; focused Flutter tests if Dart is available; `python -m unittest tools.verify.livekit_network_config.test_model`; `python -m tools.verify.livekit_network_config.check`; real SDK/SFU test only with an isolated configured target.

### Task 5: Keep final dashboard, load, physical, and rollout gates evidence-based (#173–#176)

**Files/routes:**
- `tools/verify/paired_screen_acceptance/`
- `tools/load/screen_share_matrix/`
- `tools/verify/media_qoe/`
- `evidence/media/issue-173-paired-acceptance-2026-10-07.json`
- issue comments on #173–#176

- [x] Confirm the source artifacts and prior comments exist for all four issues.
- [x] Do not mark physical paired runs, all load profiles, deployed Grafana alerts, mixed-version pilot, or rollback as passed without their required evidence.
- [x] Preserve the safe rollout `NO-GO` while dependencies remain unaccepted and keep all sensitive frames, PCM, SDP, and credentials out of evidence.

**Checks:** `python -m unittest tools.verify.paired_screen_acceptance.test_evidence`; `python -m unittest tools.load.screen_share_matrix.test_planner`; `python -m unittest tools.verify.media_qoe.test_dashboard`; `promtool check rules` and `promtool test rules` through CI; physical/SFU/Grafana gates run only in their target environments.

### Task 6: Integrate and report

**Files:** only the reviewed workstream files above plus this plan.

- [x] Run each changed capability's nearest native tests and `git diff --check`.
- [x] Review the full diff, changed file sizes, and `git status --short` before staging any files.
- [ ] Report issue-by-issue source status, comments reused/updated, test evidence, runtime `NOT_RUN` gates, and whether each issue is ready to close.
