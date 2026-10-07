# Next 20 user-authored issues — 2026-10-08

## Operating brief

- Classification: `split_first`; large issue packet across tracing, WebRTC and release/QA leaves.
- Base: GitHub issue target `origin/master` at `9b524569bb2b46b95afbb1f5040c32ceefda7214`; this branch includes the client-root migration to `clients/web` and `clients/flutter`.
- Active doctrine: preserve session isolation, server ACL, private LiveKit boundaries, and actual media lifecycle; no capacity/FPS claims without device/load evidence. Never treat mocks, templates, or build-only checks as production/device acceptance.
- Selected open issues authored by `Egkurilov`: #145, #146, #148, #157, #158, #159, #160, #161, #162, #164, #165, #166, #167, #168, #169, #170, #172, #173, #174, #175. Umbrellas and the previous batch are excluded.
- Parallel split: tracing flow contract/relay/native context (#145/#146/#148); screen contract/diagnostics/web publisher/preview/viewer (#157/#159/#160/#162/#164); Flutter publisher/viewer/capture/codec/adaptation/metadata (#161/#165–#170). Root owns real-SFU baseline (#158), integrated E2E/load/physical/Grafana acceptance (#172–#175), and integration review.
- For every item already implemented in this base, add a GitHub issue comment that states the exact remaining acceptance scenario, environment and versions, evidence fields/artifacts, and `PASS/FAIL/NOT_RUN` format. If implementation is missing, write focused tests before code.
- Keep hardware/prod-dependent gates open until the required evidence exists. Do not push, merge, deploy, or close issues in this packet.

## Route map

| Issues | Route |
|---|---|
| #145, #146 | `backend/internal/observability/ingest_client_traces` + relay contract tests |
| #148 | `clients/flutter/lib/src/features/telemetry` with `SessionScope` edge |
| #157, #159, #160, #162, #164 | `clients/web/src/voice` and shared screen-share contract |
| #161, #165–#170 | `clients/flutter/lib/src/features/screen` and platform capture/viewer owners |
| #158 | `clients/web` real-SDK/SFU test harness reusing #172 infrastructure |
| #172–#175 | existing test workflow, evidence validators, media dashboard owners |

## Stop condition

All repository-safe source work is integrated and tested; comments exist for implemented-but-unaccepted issues; every external requirement is explicitly marked `NOT_RUN` with its required evidence format.
