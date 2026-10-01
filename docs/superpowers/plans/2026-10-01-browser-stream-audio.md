# Browser stream audio controls implementation plan

> Execute inline in this task, with focused regression tests before implementation.

**Goal:** Make stream mute and volume attenuation reach the HTML audio output as well as Web Audio.

**Architecture:** Keep the existing AudioMixer interface and its 0–200% range. Use the element for attenuation up to 100%, the gain node for amplification above 100%, and silence both outputs for mute. Compensate through gain when the browser ignores native volume writes. Preserve voice/screen controls and saved preferences.

**Tech stack:** Vue 3, TypeScript, LiveKit Client 2.22.3, Vitest.

## Operating brief

- Packet 1: `review_gate`, T-005, production media telemetry; completed before code changes.
- Packet 2: `small_direct`, T-030, `frontend/src/voice/audio_gain.ts` and its exact tests.
- Doctrine: preserve current controls, 0–200% range, independent voice and screen mute, fallback and source reuse.
- Ratchet: changed production/test files remain below 120 lines; no broad conversion.
- Checks: nearest audio/controller tests and `npm run build`.
- Stop: local regression/build pass; live audio acceptance remains NOT_RUN if browser access fails.
- Open question: actual affected browser version and audible output cannot be inspected with the current browser tool error.

## Task 1: Preserve review evidence

- [x] Save anonymous aggregate measurements in `evidence/media/browser-stream-review-2026-10-01-001.json`.
- [x] Record observed dimensions/FPS separately from the requested profile and record the missing visual/audio check.

## Task 2: Regress mute and attenuation

- [x] Add cases in `frontend/src/voice/audio_gain.spec.ts` asserting:

```ts
output.setMuted(true)
expect(audio.muted).toBe(true)
expect(audio.volume).toBe(0)
output.setMuted(false)
output.setVolume(50)
expect(audio.volume).toBe(0.5)
expect(audio.volume * gain.gain.value).toBe(0.5)
output.setVolume(175)
expect(audio.volume * gain.gain.value).toBe(1.75)
```

- [x] Run `npm test -- src/voice/audio_gain.spec.ts`; expect failure on the native mute/volume assertions.
- [x] Change `WebAudioGain.apply` in `frontend/src/voice/audio_gain.ts`:

```ts
const volume = this.muted ? 0 : this.volume / 100
this.element.muted = this.muted
this.element.volume = Math.min(1, volume)
this.gain.gain.value = this.element.volume > 0 ? volume / this.element.volume : 0
```

- [x] Run the audio gain, screen audio toggle, remote voice playback and volume controls tests.
- [x] Run `npm run build`; record exact results and the remaining live acceptance limitation.
- [x] Inspect the diff, status and changed line counts. Keep production deployment as a separate packet after live acceptance.

