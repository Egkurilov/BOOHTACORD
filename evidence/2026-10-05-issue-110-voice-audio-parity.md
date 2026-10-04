# Issue #110 — voice audio parity implementation

Status: implementation supplied; acceptance NOT_RUN.

Baseline: master ba9d8e89; route split_first, profile/diagnostics/OTLP leaves.
Changes: canonical versioned profiles and Web/Dart adapters; explicit DTX/RED/
high priority; best-effort mono/48k; per-room pinning; track-scoped RTP delta
diagnostics; actual/unknown separation; anonymous export; bounded relay attrs;
private randomized A/B preparation.

Source finding: Flutter LiveKit mapped red=true to disableRed=true, while Web
requests enabled RED. Corrected through a focused negative-flag mapper and tests.
No claim is made about audible impact without the physical comparison.
Windows native track stats also avoid an all-PC fallback when a remote track is
not in the capture registry; explicit selectors resolve by sender/receiver or
fail. Physical screen/microphone scoping and native compilation remain NOT_RUN.

Preserved: approved 128000 default, saved AGC/AEC/NS/device/manual-gain preferences,
serialized microphone replacement/recovery, VAD/PTT, native fallback restrictions,
server ACL, cookie relay and LiveKit transport ownership.

## Checks

| Gate | Result | Reason |
|---|---|---|
| Focused Web profile/stats/privacy/polling/scope tests | NOT_RUN | Owner deferred grouped validation |
| Focused Flutter profile/stats/privacy tests | NOT_RUN | Owner deferred grouped validation |
| Go OTLP whitelist/privacy tests | NOT_RUN | Owner deferred grouped validation |
| Python blind matrix/privacy tests | NOT_RUN | Owner deferred grouped validation |
| Contracts/native validators, lint, builds | NOT_RUN | Owner requested code-only merging now |
| Web↔Windows four-direction actual same-mic RTP | NOT_RUN | Physical grouped run pending |
| 64/96/128 blind speech/noise/double-talk ratings | NOT_RUN | Listener evidence pending |
| Clean/1%/3% loss, silence DTX and reconnect | NOT_RUN | Controlled network run pending |
| Physical Android/iOS comparison | NOT_RUN | Devices pending |

Source review does not prove acoustic parity. No recording was generated and no
reference evidence was modified. Issue remains open until physical acceptance.
See tools/audio/voice_parity/README.md and ADR-016 for the exact protocol.
