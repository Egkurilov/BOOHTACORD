# #105 — microphone threshold and input gain

Owner scope: Web and Flutter; merge code into master without builds, deployment
or validation runs. Add focused tests for the later common run.

## Existing → new ownership

- Web audio preferences → account/device microphone-control preferences.
- LiveKit microphone adapter → derived capture graph: RNNoise (optional),
  local VAD, software gain, limiter, then publication.
- Activation store → VAD gate enabled only in VAD; PTT keeps existing mute intent.
- AudioSettings → threshold, pre-gate meter, input gain and clipping indicator.
- Flutter AudioPreferences → safe default/migration of two local numeric fields.
- AudioDeviceController → serialized native controls and local capability meter.
- Flutter WebRTC capture adapters → shared allocation-free microphone DSP;
  Windows/Android/Apple method dispatch configures that capture hook.
- Flutter audio settings → accessible sliders and explicit unsupported status.

## Implementation packets

1. Add normalization, persistence and DSP regression cases before implementation.
2. Implement Web Audio controls, hot updates, lifecycle cleanup and UI.
3. Implement shared native DSP and native method bridges. Apple keeps its
   existing coupled AEC/NS; custom RNNoise remains bypassed there.
4. Bind Flutter preferences, activation, AGC, capture and UI.
5. Inspect diffs, record NOT_RUN evidence, commit/merge with [skip ci].

## Invariants

- Threshold -70…-20 dBFS, default -50; gain 0…200%, default 100%.
- Detector reads input before gain; 6 dB hysteresis, 200 ms hold and
  20 ms lookbehind retain word onsets and tails.
- PTT bypasses detector; mute/deafen/permission and server ACL remain authoritative.
- AGC uses unity software gain without overwriting the saved manual value.
- Live changes do not disconnect/rejoin or republish the room.
- Local PCM, levels and preference values never enter backend telemetry.
- Unsupported/missing native hooks are reported; configured is not proof of
  applied processing. Only observed capture frames establish active status.

## Deferred native validation

Web focused Vitest and audio harness; Flutter preference/widget tests; native
C++ DSP cases; Windows/Android builds and device smoke; iOS hardware smoke.
All remain NOT_RUN until the owner requests the common validation scope.
