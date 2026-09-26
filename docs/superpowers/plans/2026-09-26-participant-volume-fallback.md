# Participant Volume Fallback Implementation Plan

> **For agentic workers:** Execute this plan in the assigned participant-volume agent. The user has authorized the repair.

**Goal:** Keep per-participant microphone volume adjustable during a voice call when browser storage or current-account loading is unavailable.

**Architecture:** `VoiceVolumePreferences` retains the active account's participant/screen settings in memory and writes to localStorage when possible. Binding a different account clears the cache. `voice_volume_controls` continues to apply values to `RemoteVoicePlayback`; its existing post-change synchronization will read the in-memory value instead of reverting to 100%.

**Tech Stack:** Vue 3, TypeScript, Vitest, LiveKit Client playback adapter.

---

### Task 1: Reproduce the unavailable-storage reset

**Files:** Modify `frontend/src/voice/voice_volume_preferences.spec.ts` and `frontend/src/voice/voice_volume_controls.spec.ts`.

- [x] Add a preference test whose storage `getItem` and `setItem` throw. After `bind('owner-a')` and `setParticipant('remote-a', 175)`, assert `participant('remote-a') === 175`; after `bind('owner-b')`, assert it is 100.
- [x] Add a controls test with `new VoiceVolumePreferences(null)` and a remote card. After `start()` and `setParticipantVolume('remote-a', 175)`, assert both the card volume and last `remote.setVolume` call are 175. Repeat with rejected account loading to prove the current call can adjust audio without a bound account.
- [x] Run `npm test -- src/voice/voice_volume_preferences.spec.ts src/voice/voice_volume_controls.spec.ts`; expect the new cases to fail at 100.

### Task 2: Keep current call values in memory

**Files:** Modify `frontend/src/voice/voice_volume_preferences.ts` and, if needed, `frontend/src/voice/voice_volume_controls.ts`.

- [x] Add a `Map<string, StoredVolumes>` to preferences. `read` checks it before storage; `write` updates it before attempting localStorage. `bind` clears it only when the account ID changes.
- [x] Keep normalization with `normalizeAudioVolume` and the current key format `voice-volume:v1:{owner}:{remote}`; an unbound account uses memory only.
- [x] Run the two focused specs; expect PASS. Run `npm run build`; expect PASS.

### Task 3: Verify scope and handoff

**Files:** `frontend/src/voice/voice_volume_preferences.ts`, its spec, `voice_volume_controls.spec.ts`, and this plan.

- [x] Inspect changed file sizes and `git diff --check`. Do not alter `audio_gain.ts` or screen playback FPS.
- [x] Report the corrected failure case and the limit that an actual two-client call requires live hardware/media evidence.
