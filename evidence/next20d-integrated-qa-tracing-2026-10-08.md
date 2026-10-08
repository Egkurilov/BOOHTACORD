# Next user-authored batch: tracing and media QA audit

Date: 2026-10-08 (Europe/Moscow)
Audited source: `0ee991cd42b10f33ac4e5840498a19f5db33d643` (local merged master baseline).
Issues: #146, #148, #172, #173, #174, #175. GitHub shows author `Egkurilov` for all six.

## Source status

- #146: relay sanitizer and focused Go tests are present. Existing isolated relay/Collector/Tempo evidence is tied to the tested SHA recorded in `tracing-user-flow-2026-10-07.md`; repeat session-switch smoke on this audited candidate before calling that runtime check current.
- #148: Flutter ActionScope, SessionScope binding and async/session guards are present. Existing test-engine evidence is not packaged app/device acceptance.
- #172: Playwright SDK/SFU harness and CI evidence path are present. Current local worktree lacks the Playwright executable, so the attempted invocation is NOT_RUN here. Hardware/FPS/latency acceptance remains a separate gate.
- #173: paired-acceptance JSON remains NOT_RUN for all 12 pairings; the validator only checks evidence structure and criteria.
- #174: L01–L10 versioned planner exists and explicitly emits a plan with NOT_RUN. No scalable 10–30 media-client generator or SFU capacity evidence is present.
- #175: media QoE dashboard, field mapping and alerts are present as source. This session did not verify a deployed Grafana/Prometheus/Tempo instance or live alerts.

## Checks on audited source

| Check | Result |
|---|---|
| `cd backend; go test ./internal/observability/ingest_client_traces/...` | PASS, 4 packages |
| `python -m unittest tools.verify.paired_screen_acceptance.test_evidence tools.verify.media_qoe.test_dashboard tools.load.screen_share_matrix.test_planner` | PASS, 19 tests |
| `cd clients/web; npm run test:screen-profile -- --run` | NOT_RUN: `playwright` executable/dependencies are absent in this worktree |
| `cd clients/flutter; flutter test test/features/telemetry/action_scope` | NOT_RUN: Flutter SDK is absent in this runner |

A first combined Python invocation used a nonexistent module path (`test_profiles`) and returned an import error. It was corrected to the repository's actual `test_planner` module; the corrected 19-test suite passed. No product test failed.

## Acceptance boundary

The existing comments on all six issues were updated in place with the audited SHA, local check results, exact remaining scenarios and required evidence shape. Updated comment IDs: #146 `6047857487`; #148 `6047859773`; #172 `6047908320`; #173 `6047908601`; #174 `6047908916`; #175 `6047909213`.

Physical pairing, packaged native-client smoke, isolated real-SFU integrated regression, scalable media load, and deployed Grafana/alert checks remain NOT_RUN. Required artifacts are sanitized, source-SHA-bound PASS/FAIL/NOT_RUN evidence with environment versions and per-scenario results as detailed in the respective issue comments. Do not run load against production; do not claim a device/SFU/capacity/deployment PASS from validators, mocks or source JSON.
