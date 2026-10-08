# #169 Web calibrated adaptation: serialized writer integration

Date: 2026-10-09. Base SHA: `8a6a9a3a374df215b4a7079b44557658f6c48ce0`.
Packet: small_direct, `voice/screen_adaptation/runtime_apply` and exact publisher/session ingress.
Status: source integration PASS; hardware calibration, applied production adaptation, mixed-device pilot and release acceptance **NOT_RUN / NO-GO**.

## Implemented boundary

The earlier source packet implemented a pure calibrated supervisor but left its decision-to-writer path unapplied. The new child runtime connects the real `VoiceScreenSession.readScreenDiagnostics` path to that policy and the existing `ScreenPublisherAdapter.update` only. No encoder, Room, capture, SDP writer, RTP preview, automatic second publication or telemetry stack was added. Existing start/update/stop/repair and audio ownership stay intact.

Constructor options are snapshotted, default disabled. An explicit local pilot caller must supply approved typed calibration and a classified window provider; ordinary client construction supplies neither. Missing/invalid calibration means no classifier or writer calls. There is no new remote config endpoint or environment default enabling adaptation. Existing immutable publication flags remain unchanged, including bounded simulcast=false.

Classified windows carry generation, sample time, source motion, visibility, warmup, subscriber knowledge and independently evidenced provenance/bottleneck signals. Runtime does not infer moving content, subscribers, thermal pressure, source limitations or network bottlenecks from a low FPS value. Receiver-only/unknown/static/hidden/no-subscriber/stale windows hold. Synthetic calibration exists only in test fixtures and is not hardware PASS evidence.

Tickets are captured before diagnostics or classification awaits and include owner/session identity, Room, port, track, publication generation, writer revision and reset epoch. Manual intent, busy writer, stop/cancel, changed owner/Room/track, republished generation and explicit reset reject late work. Existing writer validation remains the final media mutation boundary. Failed writes keep the previous effective policy state and preserve the manual ceiling.

The manual user ceiling is independent of an adapted effective profile. Confirmed own updates rebase writer/publication revisions while keeping that ceiling and transition budget; new manual selection establishes a new ceiling. Confirmed adaptation updates the existing effective session profile, metadata and repair watchdog, keeping their current owner checks. Regular diagnostics report the bounded adaptation reason; no private content or high-cardinality metric labels were added.

## Observed checks

- Initial regression suite was red because the runtime module was missing; tests were added before source implementation.
- Focused policy/runtime/publisher/rollout/actual-session/controls tests: **13 files / 55 tests PASS**. New runtime tests: **4 files / 12 tests PASS**.
- Covered real serialized adapter pressure/recovery, retained ceiling, default-off and no calibration, unknown/receiver/static/hidden/no-subscriber holds, manual/stop/owner/Room/publication during async classification, superseded pending writer, late stopped/replaced owner, writer rollback, async old-owner diagnostic read, provider failure, reset epoch and immutable option snapshot.
- Actual VoiceScreenSession diagnostic ingress test confirms the writer call and effective metadata publication; no isolated sidecar is substituted for production binding.
- Full `npm test`: **454 files / 1412 tests PASS**.
- `VITE_PUBLIC_ORIGIN=https://app.example.test npm run build`: **PASS** (vue-tsc + Vite). Existing LiveKit static/dynamic import and chunk-size warnings remain; no owned TypeScript errors. Initial type-check found a generic inferred-default ticket type and improperly accessed typed test mocks; both corrected and final build passed.
- `python -m tools.verify.dependencies.web`: **PASS, 1085 files**.
- `git diff --check`: **PASS**. Production child files are 14/35/67 lines; existing adapter101 and VoiceScreenSession120 satisfy the hard120 limit. The new leaf has3 production files plus one synthetic test fixture and4 direct tests.

## Unperformed acceptance

There is no approved hardware calibration or automatic production classifier in this packet. No moving-content/voice/SFU paired measurement, network shaping, thermal calibration, physical weak/healthy receiver scenario, signed deployment, pilot or rollback was performed. The caller remains default off until #158/#173/#174 establish valid inputs/calibration and #176 release gates authorize a candidate. Do not announce supported FPS, quality profiles, voice performance or GO from unit/source checks. QA transfer must retain those conditions and the full media acceptance matrix.

Slavik Gym report: route=small_direct; packet=screen-adaptation-writer-binding; tokens=estimated:11000; method=manual_estimate; driver=issue169; next_split=approved-hardware-calibration-and-pilot-QA.
