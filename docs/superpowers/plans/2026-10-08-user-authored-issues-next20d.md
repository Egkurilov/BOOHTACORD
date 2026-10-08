# User Authored Issues Next 20D Implementation Plan

> **For agentic workers:** This work is split across three requested subagents, each working in its own managed worktree and semantic `codex/*` branch. Keep changes within the assigned issue leaf; review before integrating.

**Goal:** Advance the next 20 open BOOHTACORD issues authored by Egkurilov, implement missing source work, and document concrete acceptance evidence for already implemented features.

**Architecture:** Preserve the existing LiveKit/WebRTC media transport and the current ActionScope/SessionScope design. Split work into screen-session contract and publisher lifecycle (#156–162), viewer/capture/quality policy (#164–170), and integrated QA plus tracing relay/native flow (#146, #148, #172–175). Record runtime acceptance as NOT_RUN unless exercised on the required real devices, SFU, load environment, or dashboards.

**Tech Stack:** Go, Vue 3/TypeScript/Vite, Flutter/Dart, LiveKit/WebRTC, Playwright, Grafana/Tempo.

---

### Task 1: Screen contract, baseline, publishers, preview lifecycle (#156–162)

**Files:** `clients/web/src/voice/screen_profile_contract/`, `clients/web/src/voice/screen_profile/`, `clients/web/src/voice/screen_publisher/`, `clients/web/src/voice/screen_preview/`, `clients/flutter/lib/src/features/screen/`, `clients/web/tests/screen_profile/`, and their nearest typed tests.

- [ ] Compare current master with issues #156–162; preserve established descriptor, one-publisher, selected-viewer, and preview lifecycle contracts.
- [ ] Add focused regression tests before implementing any missing contract or lifecycle behavior.
- [ ] Validate browser code with `npm test -- --run` scoped to the changed screen profile, publisher, or preview specs.
- [ ] Run `npm run test:screen-profile` and `npm run test:screen-profile-sfu` when their local browser/SFU prerequisites are available; record prerequisite failures as NOT_RUN.
- [ ] For code already present, update the issue comment with commands/results and a paired sender/viewer evidence matrix containing client build, API/SFU identity, case IDs, timestamps, expected/actual sample-window outcome, and PASS/FAIL/NOT_RUN.

### Task 2: Viewer recovery, desktop/mobile capture, codec, adaptation, UX (#164–170)

**Files:** exact screen-viewer, screen-profile, screen-adaptation, screen-profile-metadata, desktop-capture, and mobile-capture leaves under `clients/web/src/voice/`, `clients/flutter/lib/src/features/screen/`, `clients/desktop/`, and their nearest tests.

- [ ] Read issues #164–170 and map each requirement to its native entrypoint, one leaf, and nearest typed regression tests before edits.
- [ ] Keep actual capture, encode, decode, and presentation values distinct from configured targets and browser/device capability claims.
- [ ] Add a failing focused test for each code correction, then implement and rerun the relevant Web or Flutter test.
- [ ] Keep hardware codec, Android lifecycle, Windows/macOS capture, and paired-device rows NOT_RUN unless the named device/build is exercised; document sanitized metadata and expected video/log artifact format.
- [ ] Update existing issue comments with evidence and outstanding device rows; do not close issues on source-only results.

### Task 3: Tracing relay and Flutter flow; integrated smoke, paired/load acceptance, QoE (#146, #148, #172–175)

**Files:** `clients/flutter/lib/src/features/telemetry/action_scope/`, the exact OTLP relay sanitizer/forwarder leaf and its typed tests, `clients/web/tests/screen_profile/screen_share_sfu/`, `tools/load/screen_share_matrix/`, the versioned media QoE dashboard/alert files, and `evidence/media/` acceptance records.

- [ ] Verify relay identity/allowlist and Flutter async-context isolation against shared fixtures; add focused regression tests only where behavior is missing.
- [ ] Extend the real-SDK/SFU smoke and the existing media load planner without asserting RTP quality from API-only load.
- [ ] Keep paired-device, 10/20/30 participant and 4/10/20 stream soak, live network/SFU, and Grafana deployment checks NOT_RUN without the corresponding infrastructure.
- [ ] Write sanitized evidence rows with app/server/SFU/config identities, case IDs, timestamps, resource results, screenshots or query exports where applicable, and explicit PASS/FAIL/NOT_RUN.
- [ ] Update existing issue comments with exact local checks and the acceptance procedure/artifact required; do not close issues.

### Integration and packet closeout

- [ ] Review all three commits for exact issue scope, conflicts, file-size ratchets, and `git diff --check` before cherry-picking.
- [ ] Run the nearest native tests plus `tools/verify/contracts/verify-contracts.ps1` and `tools/verify/spec_traceability/verify-spec-traceability.ps1` if contracts/backlog changed.
- [ ] Confirm every selected issue has a current implementation/acceptance comment and remains open where runtime gates are incomplete.
- [ ] Integrate reviewed commits into this packet branch; leave push, deployment, and issue closure out of scope.
