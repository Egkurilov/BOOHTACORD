# #105 — microphone activation threshold and input gain

Date: 2026-10-05
Implementation branch: codex/issue-105-microphone-controls
Baseline: db7b77baab767e0c4957289800314cdedd5fc60d (master)
Requirements: REQ-AUDIO-01, REQ-VOICE-01; backlog leaf T-022.
Decision: ADR-015 extends the VAD scope of ADR-014.

## Delivered code

- Web and Flutter: local account/device preferences, safe defaults and clamping,
  threshold/gain sliders, reset controls, pre-gain level/threshold meter, clipping,
  PTT threshold bypass and manual gain disabled while AGC is selected.
- Web: real AudioWorklet before LiveKit publication, optional RNNoise composition,
  live messages without rejoin/recapture, muted publication, reset acknowledgement,
  derived-only cleanup and explicit processor failure.
- Native Flutter: shared capture DSP, Windows dispatch, Android JNI/direct buffer,
  Apple writable capture hook. Apple RNNoise bypass and AEC/NS behavior remain.
- Threshold: -70…-20 dBFS, default -50. Gain: 0…200%, default 100.
  Hysteresis 6 dB, hold 200 ms, lookbehind 20 ms; immediate zero, ramped gain,
  output saturation. PTT bypasses gate and delay.
- Native supported input: mono 10 ms S16-scaled float blocks, 8…96 kHz.
  Unsupported formats are explicit and fail closed.
- Meter is available with an enabled microphone in a call; idle/muted states
  clear local readings. Neither meter values nor settings enter backend telemetry.

## Preservation and manual source inspection

- Retained the serialized adapter queue, generation invalidation, device recovery,
  constraints, SDK mute intent and publication retry.
- Physically split the large Web microphone adapter and Flutter preference/profile
  code by existing method/import edges. Forward exports preserve existing callers.
  AudioPreferences public methods remain instance methods (including overrides).
- Checked installed LiveKit source: setProcessor receives original capture and
  borrowed AudioContext; SDK unmute enables original capture.
- RNNoise intermediate track is enabled only after its reset/unmute; the final
  output is enabled by the adapter after its current intent check.
- PTT transition mutes capture before bypassing the gate; PTT joins start as
  listeners, then register the existing key handler.
- Legacy large workspace/plugin dispatch files receive binding changes only;
  their broader migration remains outside this feature packet.

## Validation results

Owner requested code merges without new builds or the common validation run.
No tests, compiler/analyzer, contract/spec validators, smoke or builds were run.

| Check | Status |
| --- | --- |
| Web normalization/account persistence regression tests | NOT_RUN |
| Web synthetic VAD, onset/tail, PTT, gain, clipping, AGC tests | NOT_RUN |
| Web hot controls/derived ownership and accessible SSR tests | NOT_RUN |
| Existing Web microphone device/reconnect/mute regressions | NOT_RUN |
| Flutter preference/account, capability and widget tests | NOT_RUN |
| Native C++ microphone DSP test registered in CMake | NOT_RUN |
| Flutter analyze, Windows/Android builds | NOT_RUN |
| Windows/Android physical capture and live changes | NOT_RUN |
| iOS build and physical-device capture, PCM/order confirmation | NOT_RUN |
| Contract/spec validators | NOT_RUN |
| Release builds/deployment | NOT_RUN |

## Deferred acceptance

#105 remains open for the shared validation scope and physical device evidence.
This record establishes code delivery, not acoustic quality or release readiness.
