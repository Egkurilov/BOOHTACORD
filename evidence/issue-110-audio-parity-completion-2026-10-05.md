# Issue #110 — measurement and privacy completion

Date: 2026-10-05. Source: codex/issue-110-audio-parity-completion; intake
f981b562, integrated master 10f1eba3. The commit containing this record identifies
the reviewed implementation. Acoustic acceptance: **NOT_RUN**, issue remains open.

## Preserved behavior and fixes

- Canonical 128k default and session-local 64/96k A/B candidates retained.
  Saved AGC/AEC/NS, native ADR-014 fallbacks, microphone ownership, PTT, gain,
  screen audio and server ACL/media boundaries remain under existing owners.
- Web/Dart counter history rebaselines a reused report ID when SSRC, codec,
  media source, MID or transport changes. Byte/packet rollback invalidates the
  whole interval. Stale/duplicate timestamps cannot rewind a valid baseline.
  Missing statistics remain unknown; whitespace cannot become measured zero.
- Anonymous export now projects a closed field set at root/capture/sample levels.
  Untrusted profile/codec labels, SDK/device/account/track/SSRC fields, local
  levels and PCM cannot escape through extra SDK properties.
- Opus stats cannot establish RED disabled. Both clients report unknown unless
  RED is explicitly identified; UI explains negotiated flags versus packet proof.
  RED stays enabled in production; the test-only override isolates its overhead.

## Actual media setup

Chrome 154.0.8037.95 on Windows; Web LiveKit SDK 2.22.3, isolated LiveKit 1.13.7.
Flutter LiveKit 2.13.0 / flutter_webrtc 1.6.2+hotfix.3; Flutter 3.47.5/Dart 3.13.4.
Synthetic mono 440Hz oscillator, AudioContext 48k, gain 0.2. Two independent browser
contexts publish/receive actual microphone-source RTP using production profile
options and diagnostics. No user microphone, speech, recording or PCM export.
Loopback-only SFU on a private test host reached through an owned SSH TCP tunnel.
This path does not establish UDP packet-loss behavior or hardware capture parity.

Outbound active window: four 2-second intervals. Receiver: two polls with the first
used as a baseline. Quiet: zero oscillator gain, 6s settling, four 2s intervals.
This is a short tone/zero-input transport check, not a 30s speech/noise trial.
Payload counters exclude RTP/transport headers; they are not link bandwidth.
Definitions: [WebRTC Stats](https://www.w3.org/TR/webrtc-stats/).

| Encoder cap | Requested RED | Active outbound kbit/s | Inbound kbit/s | Quiet kbit/s |
| --- | --- | --- | --- | --- |
| 128k | on | 258.80 | 258.58 | 0.114 |
| 64k | on | 130.85 | 130.73 | 4.398 |
| 96k | on | 194.32 | 195.75 | 0.114 |
| 64k controlled pair | on | 130.76 | 130.68 | 0.114 |
| 64k controlled pair | off | 64.36 | 64.35 | 0.076 |

Same-cap RED on/off ratio: **2.0316**. Stats reported Opus in both cases. This
supports the conservative RED diagnostic and explains excess payload rate in
this setup; it does not establish acoustic preference. Quiet results vary between
runs; reduced payload rate alone does not prove that every packet uses DTX.
Raw anonymous numerical records: issue-110-audio-parity-measurements-2026-10-05.json.

## Native checks

- Red before implementation: Web epoch/export assertions 7 failed; Flutter 6 failed.
  Opus/RED uncertainty failed once in each client; native UI explanation failed.
- Focused Web profile/diagnostics/export: 21 PASS. Focused Flutter: 18 PASS.
- Full Web unit suite: 1092 PASS; Vue/TypeScript/Vite build PASS. Existing bundle
  size/static-dynamic LiveKit import warnings remain; no build error.
- Full Flutter native entrypoint: app 635 PASS, LiveKit 435 PASS + 1 existing skip,
  WebRTC 24 PASS; analysis 37 informational findings, no errors/warnings.
  Integration repeat after updated master: app 637 PASS, same SDK/analysis results.
- Go authenticated trace-ingest leaves PASS, including audio vocabulary/privacy.
- Blind-trial generator: 4 PASS. Contracts and traceability (39 requirements) PASS
  using canonical tools/verify entrypoints; obsolete scripts/ wrappers are absent.
- Actual three profiles plus controlled RED comparison: 4 PASS.
- Initial full browser run: 16 PASS / 5 failures from absent generated RNNoise
  assets. Prepared pinned Emscripten 4.0.20 build validates upstream/model hashes;
  WASM SHA-256 c9e99c9a9b04c8a9f048f3961f95657c3d0b21cf6280d1d518dbf63aeedd1604.
  Prepared full browser repeat: **21 PASS**, including RNNoise graph/lifecycle,
  processed LiveKit pair, microphone join/restart/fallback and all profile tests.
  GitHub CI is the pending source-bound Windows/Android build receipt.
- Generated assets, temporary credentials, SDK console logs and build outputs are
  excluded from Git. Temporary SFU/compiler containers, archives/workspace and the owned SSH tunnel
  were removed and absence verified (PASS).

## Still required for issue acceptance

Web→Windows, Windows→Web, same-platform physical trials on the same microphone,
blind 64/96/128 ratings (clean/keyboard/fan/double-talk), isolated real 1%/3% loss,
and physical Android/iOS sender/receiver evidence: **NOT_RUN**. Operator/device
availability was requested. Local Windows C++ and mobile hardware gates are not
substituted by unit tests or a tone. ADR-016 promotion remains NOT_RUN; #110 cannot
close until comparable speech quality and the minimum passing cap are established.
