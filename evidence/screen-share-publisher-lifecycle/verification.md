# Screen-share publisher lifecycle verification

- Date: 2026-10-07
- GitHub issues: #160 Web, #161 Flutter
- Leaves: T-035 (Web), T-036 (Flutter)
- Base source revision: `e4cace80`; target branch had nine newer commits at
  validation start. PR CI must rerun all checks on the rebased commit.
- Rebased on `origin/master` at `17f27344`; Web checks below were rerun after
  resolving upstream telemetry/lifecycle changes.
- Environment: Windows, Node.js 24.18.0, LiveKit JS 2.22.3; Flutter SDK is
  unavailable locally.

## Source behavior

- Both clients now sequence publisher lifecycle operations and preserve their
  current capture through a profile republish. Web uses public LiveKit JS
  `unpublishTrack(track, false)` / `publishTrack(track, plan)`; Flutter uses the
  local LiveKit publisher runner and a sender-parameter lock shared by internal
  dynacast/degradation writers.
- The shared contract maps cancel, superseded, success, and failure outcomes.
  Stale starts are cleaned up, updates retain only latest intent, rollback
  restores the prior confirmed profile when possible, and stop does not touch
  the microphone.
- Web diagnostics reads are observational. A separate, generation-bound
  watchdog can perform one bounded repair after stable drift. Managed
  unpublish/rebind is distinguished from OS-ended capture.

## Results

| Check | Result | Evidence |
|---|---|---|
| Web full Vitest suite | PASS | `npm test` — 386 files, 1,193 tests after rebase. |
| Web production build/typecheck | PASS | `npm run build` completed; Vite reports chunk-size and ineffective dynamic-import warnings but exits successfully. |
| Web publisher focused suite | PASS | 10 files / 42 tests; profile contract and diagnostics subset 5 files / 20 tests. |
| Contracts | PASS | `tools/verify/contracts/verify-contracts.ps1` — `Contracts OK.` |
| Requirement traceability | PASS | `tools/verify/spec_traceability/verify-spec-traceability.ps1` — 39 requirements referenced. |
| Baseline browser gate | 1 PASS, 1 SKIP | `npm run test:screen-profile`; isolated SFU test skipped because short-lived publisher/viewer credentials were not provided. |
| Flutter app/vendor tests and analysis | NOT_RUN | `python -m tools.ci.native.flutter` exits: required executable `flutter` is unavailable. |
| Flutter Android/Windows native rebuild | NOT_RUN locally | Await PR CI runners with pinned Flutter 3.47.5. |
| SFU, reconnect/dynacast, two-client metadata, and audio continuity | NOT_RUN | Requires isolated LiveKit/SFU credentials and runtime environment. |
| Physical Android/Windows capture and presentation acceptance | NOT_RUN | Requires supported devices and collected device evidence. |

The skipped baseline test is not a passing SFU measurement. Build success does
not prove publisher behavior on devices. Keep both GitHub issues open until
their runtime and device acceptance items have evidence.
