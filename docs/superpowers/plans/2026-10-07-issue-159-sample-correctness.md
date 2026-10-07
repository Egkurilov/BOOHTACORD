# Issue 159 sample correctness implementation plan

> **For agentic workers:** Use the existing parallel implementation packet; this worker owns Web/Flutter collection, root owns server/relay acceptance.

**Goal:** Correct interval and provenance semantics of actual media diagnostics without a second exporter.
**Architecture:** Retain generation-scoped controllers and the single 1s sender stats poller. Match remote loss by outbound identity, guard counter intervals, export selected and total bitrate independently; raw receiver stats expose SDK-omitted durations. Preserve source activity as unknown rather than infer network failure from low FPS.
**Tech Stack:** Vue/TypeScript/Vitest, Flutter/Dart/flutter_test, Go/OpenAPI owned by integrator.

---

## Operating brief
workflow_class=split_first; task_size=large; structure_mode=structure_no_rg.
Routes: web screen sender/receiver diagnostics; Flutter screen metrics and receiver sampling.
Preservation: old report keys and ACL unchanged; unknown optional counters absent.
Ratchet: new source <=120 lines; no mixed aggregate rewrite.
Stop: focused fixtures, Web suite/build, Flutter tests/analyze and pipeline tests PASS; physical two-device and overhead acceptance NOT_RUN.

### Task 1: Guard per-layer intervals
Files: screen_sender_layers.ts/spec.ts, Flutter metrics/layers.dart/models.dart/livekit_layers.dart; tests screen_share_layer_sampling_test.dart and screen_share_livekit_layers_test.dart.
- [x] Add signed-loss correction fixture: progressing frames remain ACTIVE, loss unavailable.
- [x] Add inactive/reactivated and stale/cached interval fixtures.
- [x] Reject mismatched remote.localId/SSRC and audio outbound; sum only comparable byte intervals without summing FPS.
Run `npm test -- src/voice/screen_sender_layers.spec.ts` and focused Flutter tests; expect initial assertion failure then PASS.

### Task 2: Expand actual selected-layer and receiver collection
Files: sender diagnostics/report_media types/fields, Flutter metrics/sample.dart and narrow numeric helpers; receiver diagnostics/reader and native receiver sampling leaves.
- [x] Compute encode/decode/jitter-buffer per-frame averages using counter deltas, actual NACK/PLI/FIR and retransmission bytes where available.
- [x] Export stats_window_ms and stats_source only for valid intervals, keep total_bitrate_kbps distinct from selected_layer_bitrate_kbps.
- [x] Reset windows on stream/SSRC/generation; unavailable snapshots cannot produce healthy zero metrics.
Run `npm test -- src/voice/screen_receiver_diagnostics.spec.ts` and native receiver fixture tests.

### Task 3: Presentation and lifecycle evidence
Files: screen_playback_fps.ts, screen_playback_quality.ts, ScreenViewer.vue, native receiver report.
- [x] Record first rVFC callback elapsed time; export web_rvfc presentation provenance; native rendered/texture counters remain unsupported presentation.
- [x] Preserve SDK cumulative freeze count/duration separately from frame-gap guesses.
- [x] Keep cleanup and in-flight generation guards, avoid cached-row freshness renewal.
Run `npm test`, `npm run build`, Flutter focused tests and analyze. Record exact results in evidence/media/issue-159-sample-correctness-2026-10-07.md.

### Task 4: Integrate server contract
- [x] Cherry-pick root server/OpenAPI/relay commit, run contract checks and API rejection/privacy compatibility tests.
- [x] Inspect status/file lengths, stage exact owned files, commit, push semantic branch and create PR with honest physical acceptance gaps.
