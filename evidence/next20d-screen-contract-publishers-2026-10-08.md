# Screen-share contract, baseline, publisher, and preview review

- Review date: 2026-10-08
- Reviewed source: `0ee991cd42b10f33ac4e5840498a19f5db33d643`
- Scope: GitHub #156–#162; source work was already merged in the reviewed baseline.
- Local environment: Windows, Node.js/npm, Go. Flutter/Dart SDK unavailable.

## Source review

- #157: versioned v1 descriptor schema, profile catalog, shared lifecycle/profile fixtures, ADR-018 ownership/SLO protocol, Web/Flutter/backend contract checks are present.
- #158: test-only minimal publisher/viewer harness, numbered moving synthetic source, user-selected display capture, secure target guard, sanitized numeric report and documented repeat protocol are present. No SFU endpoint or credentials were supplied.
- #159: per-layer source diagnostics and bounded sampling are present per `evidence/screen-share-per-layer-diagnostics/verification.md`; runtime provenance and paired acceptance remain unproven.
- #160/#161: Web and Flutter publisher lifecycle adapters and shared lifecycle outcomes are present per `evidence/screen-share-web-publisher-160/verification.md` and `evidence/screen-share-publisher-lifecycle/verification.md`.
- #162: unselected screen-video preview subscriptions were removed; discovery remains publication-based and fallback thumbnails do not require RTP subscriptions. Existing #140 deadline work was not changed.

## Checks run at reviewed source

| Check | Result |
|---|---|
| Web screen-profile, publisher, thumbnail and viewer focused Vitest | PASS — 19 files, 71 tests |
| Browser screen-profile harness | PASS — 7 tests; 1 isolated LiveKit test skipped for missing lab credentials/target |
| Go screen-profile contract and descriptor API/Postgres/LiveKit packages | PASS — 4 packages |
| Contract validator | PASS — 19 tests; OpenAPI lint and parity (89 public operations, 3 private exclusions) |
| Requirement traceability | PASS — 39 approved requirements |
| Web TypeScript and production build | PASS when run with `VITE_PUBLIC_ORIGIN=https://v.bootybay.ru`; Vite emitted existing LiveKit mixed-import and >500 kB chunk warnings |
| Flutter/Dart unit tests and analysis | NOT_RUN — SDK unavailable |
| `git diff --check` | PASS |

An initial production build without the required `VITE_PUBLIC_ORIGIN` exited before compilation. Re-running with the configured production origin above succeeded. `npm ci` reported one high-severity dependency advisory; no audit fix was applied in this task.

## Acceptance still required

The harness baseline, cross-client descriptor round-trip, real SDK/SFU publisher lifecycle, native capture/presentation, and real subscription/decoder counts have not run. For each applicable scenario, attach sanitized JSON evidence with source/build SHA; Web, Flutter, LiveKit SDK, SFU image digest, OS/browser/device class and network profile; exact scenario and repeat; requested/effective descriptor/profile and active layer; aggregate capture/encode/decode/presented metrics and active subscription/resource counts; voice/screen-audio continuity; and `PASS`, `FAIL`, or `NOT_RUN` plus reason. Keep tokens, SDP, IP/candidate identifiers, user IDs, frames, PCM, and raw participant identifiers out of evidence.

Use #157/ADR-018's 30-second warm-up, 180-second capture, one-second windows, five repeats, at least 120 moving-content windows, and 20 first-frame and switch samples per repeat. #158 requires product-vs-minimal-client paired runs on the same isolated SFU/device/network, synthetic and actual display capture separated, and one-factor-at-a-time comparisons. #160/#161 require rapid profile updates, update with Dynacast, stop/logout during awaits, publish failure, reconnect/republish, OS stop, cleanup counts and microphone/voice continuity. #162 requires a room with 20 publications, zero screen-video subscriptions before selection, only selected A after selection, lifecycle/late-cleanup cases, and actual SDK subscription/decoder counts before/after. Do not infer a runtime PASS from unit tests or the skipped SFU case.

## Epic status

#156 remains open. This review covers the source-code stage for #157–#162 only. The rest of the epic (#163–#176), as well as the runtime and physical acceptance listed above, is outside this packet or still NOT_RUN; no 60 FPS or release claim is made.
