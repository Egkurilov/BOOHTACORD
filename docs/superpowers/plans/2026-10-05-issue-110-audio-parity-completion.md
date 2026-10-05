# Issue #110 voice parity completion plan

> Inline execution follows project SKILL.md. The referenced executing-plans skill
> is unavailable on this host; no delegated agents are used.

**Goal:** Correct remaining measurement/privacy defects and exercise actual codec
profiles through browser/LiveKit while preserving the physical listening gate.
**Architecture:** Retain the canonical profiles, room pinning and existing media
owners. Use matching interval guards and strict report projections in Web/Dart.
**Tech Stack:** Vue/TypeScript, Flutter/Dart, LiveKit, Playwright and Python.

## Operating brief

workflow_class=split_first; task_size=large; structure/search=structure_no_rg.
Baseline f981b562/master; integrated 10f1eba3/master without source conflicts. Primary checkout and untracked build outputs preserved.
Routes: voice/audio_diagnostics (counter epochs), voice/audio_report (safe export),
tests/audio/voice_parity (actual synthetic media), tools/audio/voice_parity (protocol).
Ratchets: 100 target/120 hard lines; 8 target/16 hard production and direct tests.
Task T-022 depends T-006/T-020; T-070/ADR-014 preserves capture/DSP restrictions.
Stop when source changes and native checks are merged and concrete review evidence
is available. Never turn synthetic/unit/build results into physical acoustic PASS.
No default/certificate/codec removal, no user recording and no backend media proxy.

## 1. RTP counter epoch preservation

Modify Web `src/voice/audio_diagnostics/{stats.ts,model.ts}` and Flutter
`lib/src/features/voice/audio_diagnostics/stats.dart`. Add interval helpers there
and direct Web/Flutter epoch tests, preserving native import edges.

- [x] Write failing tests: unchanged report ID with another SSRC/codec, backwards
  timestamp, bytes/packets rollback, duplicated snapshots and numeric whitespace.
  Expected assertion after replacement: `expect(sample.bitrateBps).toBeNull()`;
  next fresh report recovers a rate without borrowing the previous source counters.
- [x] Run `npm test -- src/voice/audio_diagnostics` and
  `flutter test test/voice_audio_stats_test.dart test/voice_audio_epoch_test.dart`;
  record the failure before changing the implementation.
- [x] Implement source-epoch comparison and invalidate all interval fields on
  byte/packet reset; ignore stale timestamps instead of rewinding the baseline.
  Guard example: `old.ssrc !== next.ssrc` prevents mixing two stream counters.
- [x] Repeat the focused suites; existing silence/duplicate/codec cases must pass.

## 2. Anonymous report capability

Create Web `src/voice/audio_report/{export.ts,export.spec.ts}` and Flutter
`lib/src/features/voice/audio_report/export.dart`, with
`test/voice_audio_report_test.dart`. Preserve old model methods as thin bindings.

- [x] Red-test unknown properties on root, capture and samples, including device
  labels, SSRC/track/account IDs and local audio levels. Assertion:
  `expect(serialized).not.toContain('private-marker')`.
- [x] Implement a closed field projection; keep only bounded profile/codec names,
  capture format/processing flags and numeric RTP measurements. Do not export PCM.
- [x] Repeat report/telemetry/privacy tests and Go relay whitelist/privacy tests:
  `go test ./internal/observability/ingest_client_traces/...` in backend.

## 3. Actual browser profile measurements

Create `clients/web/tests/audio/voice_parity/{fixture.ts,profiles.browser.spec.ts}`;
add one fixture script binding in `tests/audio/fixture.html`. Use the existing
`tools/audio/browser_runner.mjs` and loopback-only development LiveKit server.

- [x] Add browser expectations before the fixture: each canonical profile returns
  actual sender cap, Opus codec/48k RTP and positive independent receiver rates.
  Expected assertion: `expect(result.senderCap).toBe(profile.maxBitrate)`.
- [x] Generate mono synthetic audio locally, publish through production profile
  options, collect using production diagnostics, then set gain to zero for DTX.
  Measure speech-like tone/silence windows; never use these as listener evidence.
- [x] Run `npm run test:audio:browser -- voice_parity` with isolated SFU and Chrome.
  Retain only anonymous numerical results; test cleanup closes tracks/rooms/contexts.
- [x] Remove the temporary SFU container/tunnel after tests, with exact label checks.

## 4. Integration and review

- [x] Run full Web tests/build and `python -m tools.ci.native.flutter` on integration
  source; repeat microphone/device/PTT/reconnect tests included in native suites.
- [x] Run Python parity tests and project contract/traceability validators. Inspect
  status and changed file sizes before staging exact source/test/evidence paths.
- [ ] Commit per capability, push a semantic codex branch, create/attach a PR and
  merge after relevant CI succeeds. No release tag is needed for this code packet.
- [x] Record actual browser numbers, source/SDK versions and all observed outcomes
  in `evidence/issue-110-audio-parity-completion-2026-10-05.md`.
- [x] Keep Web↔Windows same-microphone/blind listener, controlled 1%/3% loss and
  physical Android/iOS gates open until corresponding evidence is supplied.

Measured RED overhead is isolated by an on/off test at the same 64k cap.
Opus stats do not prove RED disabled; both clients keep absent evidence unknown.

## Unresolved physical input

The operator's microphone/listener availability is requested asynchronously.
64/96 remain candidates until the issue's physical A/B and ADR promotion condition
is met. Existing ADR-016 already establishes this boundary.
