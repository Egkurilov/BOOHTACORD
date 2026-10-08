# Native slow adaptation runtime binding — #169

Date: 2026-10-09. Base: `8a6a9a3a374df215b4a7079b44557658f6c48ce0`.
Source verification: PASS. Calibrated production activation and physical media acceptance: NOT_RUN / NO_GO.

## Implemented source boundary

`screen/slow_policy` mirrors the existing Web typed classifier input and calibrated hysteresis: fresh generation windows, independent provenances, separate motion/text ladders, consecutive pressure windows, recovery, dwell, transition and attempted-write bounds. Receiver-local pressure, mixed/unknown signals, static/hidden/paused/stopped sources, unavailable subscribers, stale/duplicate windows and warm-up do not trigger profile writes.

`screen/runtime_apply` connects optional explicitly approved classification to the real `ScreenShareController` and metrics sampler. The binding is captured before asynchronous native getStats; the classifier must return a typed window with the captured generation and observation clock. No bottleneck, source motion, subscriber count, visibility or warm-up is inferred from FPS. Calibration is copied into immutable maps/lists. Production supplies no calibration or classifier; `enabled` defaults to false.

The only mutation edge is existing `updateScreenShareQuality(..., fromSupervisor: true)` → serialized native driver → existing guarded `updateScreenShareTrackProfile`. It keeps the active capture track. No SDP, encoder-parameter, capture, voice, Dynacast, descriptor or rollout-flag mutation is added. The existing writer now also checks transport session and deployment boundaries before committing.

Manual user quality remains an independent ceiling; adaptive effective quality does not overwrite saved user settings. Explicit manual start/update resets adaptation. Stop/dispose, replaced account or transport session, deployment, room, track, publication, metrics generation and manual writer revision reject late observations and mutations. Old diagnostic collectors cannot invalidate a newer manual generation. Restored writer failures preserve confirmed quality and the per-generation attempt bound.

## Native capability limits

The source can apply supported profiles through the existing writer: Windows resolution changes at unchanged capture FPS, and existing iOS encoder-only steps. Tests prove the Windows 1080p60 → 720p60 contract with the same track, VP8, one layer and disabled backup codec.

Existing Windows FPS changes and macOS/Android resolution or FPS changes require platform capture replacement. This packet preserves that behavior: automatic adaptation returns `capture-restart-required`, performs no write and does not restart capture. It does not claim those unavailable transitions are implemented or measured. Broader #169 rollout, individual layer/budget policy and physical platform acceptance remain separate work; no synthetic PASS calibration is installed in production.

## Preservation and validation

- Baseline before implementation: 22 existing profile/capture/rollout tests PASS.
- RED: native binding test could not compile without the missing real controller/options/runtime edge. RED: late old diagnostic collector erased a newer manual state; regression fixed.
- Focused native policy/runtime/actual-controller tests: 16 PASS, including actual metrics ingress, pre-getStats and async-classifier boundaries, supported profile delegation, restored rollback and bounded attempts.
- Preservation plus focused command: `flutter test --no-pub test/features/screen_adaptation test/screen_share_quality_test.dart test/screen_share_capture_plan_test.dart test/features/screen_rollout/policy_test.dart test/features/screen/capture/update_notice_test.dart` — PASS (41 tests).
- Full `flutter test --no-pub` — PASS, 989 tests; one existing relay tempo test skipped.
- Scoped `dart analyze` for runtime_apply, slow_policy, lifecycle, metrics, quality and their direct tests — PASS, no issues.
- Full `flutter analyze --no-pub` — no errors/warnings; 56 existing informational findings outside this packet. Its nonzero exit for informational findings is retained truthfully.
- Canonical `python -m tools.ci.native.contracts` — PASS: 260 tests (one existing skip), 19 tests and 2 SBOM checks; OpenAPI 108 public operations / 3 private exclusions; contract, traceability, Dart feature/UI boundaries and workflow checks PASS.
- `git diff --check` — PASS. All changed production files and direct Dart test files at or below 120 lines; policy/runtime leaves contain six/five production files.

The SDK writer contract uses a mock participant to inspect the actual native driver call; it is not physical SFU/codec/load evidence. Private sessions, media tokens and user content are absent from fixtures and evidence. Physical voice continuity, measured sender bitrate/FPS, CPU/thermal behavior, sustained calibration and receiver-local isolation remain NOT_RUN under QA #227. No push, issue change, build distribution or deployment occurs in this packet.
