# ADR-015 — local microphone activation and prepublication input gain

Status: accepted for implementation by owner request #105; hardware validation
NOT_RUN. Extends ADR-014's earlier exclusion of custom VAD. REQ-AUDIO-01 and
REQ-VOICE-01 remain subject to their existing evidence gates.

## Decision

Add a local energy gate with a configurable -70…-20 dBFS opening threshold,
default -50. Measure RMS before software gain, after the existing noise
processing. Close below threshold minus 6 dB after a 200 ms hold. A fixed
20 ms delay retains the beginning of words. PTT bypasses the gate and delay.
Manual mute, deafen, permissions and the SDK capture lifecycle remain authoritative.

Input gain is 0…200%, default 100. It changes microphone PCM before publication;
participant playback volume and operating-system gain are independent.
Nonzero changes ramp at 100 percentage points per 10 ms. Zero immediately
silences output. Saturate at normalized +/-1 (native S16 -32768…32767) and
report clipping locally. AGC selects unity software gain; keep the saved manual
value so disabling AGC restores it.

Web uses an AudioWorklet after optional RNNoise. The SDK owns capture and the
AudioContext; processors own derived nodes/tracks. Hot preference updates only
send worklet control messages. Publication begins muted and reset/unmute
acknowledgement precedes enabling the derived output.

Flutter uses the existing persistent capture post-processing hooks and a shared
C++ processor. Support mono 10 ms float PCM blocks on the WebRTC S16 scale,
8–96 kHz. Unsupported blocks are silenced and reported explicitly. The callback
uses fixed storage; no allocations, locks, channel invocations or retained caller buffers. The bounded 20 ms lookbehind
is cleared on capture/mode generation changes.
On Apple, the hook runs gain/VAD only and preserves the existing coupled AEC/NS;
custom RNNoise stays unsupported as specified in ADR-014.

Preferences belong to the local authenticated account and browser profile/app
installation. They never reach the backend. Numeric fields normalize missing,
non-numeric and non-finite values to safe defaults. The existing Flutter v1
payload gains two optional fields; Web uses its own local versioned key.

Meter and clipping state remain local. No new telemetry includes PCM, exact
levels or preference values. No backend/SFU/ACL or screen-audio changes.

## Acceptance still required

Run the focused tests and existing capture/recovery/PTT regressions, build the
native targets and verify physical Android, Windows and iOS devices. In
particular, verify processor order, writable PCM format, clipping, onset/tail
retention and AGC transitions on those devices. Configured/initializing status
is never evidence that capture frames were processed.
