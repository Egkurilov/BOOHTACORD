# Issue 95 / IMP-31: restricted transport evidence

As of 2026-10-05. Source measured:
`f97aaee04a159033cfc8a4540f8fab8d96b25426` (clean tracked checkout).
Measured at `2026-10-05T10:35:52.262340+00:00`.
Raw anonymous numeric projection:
[matrix](issue-95-restricted-networks-measurements-2026-10-05.json).

## Stand and method

Isolated Linux Docker 29.5.3, two headless Chromium 153.0.8010.12 contexts;
Node 22.22.3 in a disposable CPU/memory-bounded browser container. Production
Node pin is 24.18.0; this stand is not the source CI toolchain acceptance.
LiveKit 1.13.7 pinned image digest is retained in the matrix. Synthetic 440 Hz,
mono 48 kHz, production 128 kbit/s cap and RED; no user microphone or recording.

The first experiment omitted Docker published mappings only. It incorrectly
allowed direct bridge-address UDP candidate connectivity, and its strict TCP
assertion failed. It was not accepted as UDP-blocked PASS. The fixture now
drops the restricted transports in the owned SFU namespace, never the host
namespace, and also omits their mappings. Each container was removed in `finally`.

## Observations (receiver; ms rounded for readability)

| Condition | Signal | ICE observed | SDK join | RTP growth observed | Selected path | Connectivity |
|---|---:|---:|---:|---:|---|---|
| baseline | 339 | 458 | 458 | 1821 | UDP | PASS |
| UDP blocked | 277 | 495 | 495 | 1927 | TCP | PASS |
| both media transports blocked | 298 | unknown | unknown | unknown | none | FAIL |
| signal socket unreachable | unknown | unknown | unknown | unknown | none | FAIL |
| restored fresh join | 321 | 442 | 442 | 1805 | UDP | PASS |

All five **measurement gates PASS**: the expected observations were reproduced.
This does not make the two connectivity FAIL profiles supported. Receiver audio
bytes were 31056 / 31709 / 31716 on baseline / UDP-blocked / recovery, with
positive counter growth. The signal-only failure elapsed 12313 ms; no ICE/RTP
was inferred from successful signal. Failure strings were not exported.

The restoration row uses a fresh manually equivalent join, not automatic
in-place reconnect. Signal is local WS and fixture grants are short-lived dev
credentials; this does not prove production TLS or server-side admission.
First observed ICE and RTP are sampling milestones, not exact packet arrival
or audible quality. SDK join excludes the Go admission requests.

## Source verification

- Web: 1100 tests PASS (343 files), including 7 new observer/privacy cases.
- Production Web build PASS; existing chunk warnings remain.
- Native fixture/safety tests: 6 PASS after the local-Docker/namespace guards.
- Contracts PASS; traceability PASS for 39 requirements; links PASS.
- Source-bound GitHub CI and its retained matrix are the integration gate;
  later fixture safety changes must be remeasured before integration.

## Remaining gates and decision

- Physical home network: NOT_RUN.
- Physical mobile hotspot: NOT_RUN (operator access requested, no consent received).
- Production TLS/admission/revocation over relay: NOT_RUN.
- QA-06 acoustic/capture acceptance and QA-09 capacity: NOT_RUN for this packet.
- TURN promotion: NO_GO until the conditional
  [ADR-017](../docs/adr/ADR-017-restricted-network-turn-tls.md) gates pass.

Issue 95 stays open. The implemented observer and
[runbook](../docs/runbooks/restricted-networks.md) make the physical matrix
repeatable without publishing ICE addresses. Production TURN is not enabled.
