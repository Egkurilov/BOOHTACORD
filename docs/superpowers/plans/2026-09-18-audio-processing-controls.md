# Audio processing controls implementation plan

> **For Codex:** Execute this plan task-by-task, with tests first and each check recorded below.

**Goal:** Let a connected user control browser-provided AGC, echo cancellation, and noise suppression without adding custom DSP.

**Architecture:** Keep a single immutable audio-processing preference in the voice session. Build microphone capture constraints from it; apply only the supported processing subset to an already published LiveKit local audio track. The settings UI dispatches the preference through the existing connection store and presents no claim that an unsupported browser constraint was honored.

**Tech Stack:** Vue 3, TypeScript, Pinia, Vitest, LiveKit JS client, browser MediaTrackConstraints.

---

### Task 1: Model microphone-processing constraints and LiveKit adapter edge

**Status:** Complete — focused gateway tests passed.

**Files:**
- Modify: `frontend/src/voice/media_publishing.ts`
- Modify: `frontend/src/voice/livekit_gateway.ts`
- Test: `frontend/src/voice/livekit_gateway.spec.ts`

1. Write failing tests for the default AGC/echo/noise constraints and for applying only these constraints to an active local microphone track.
2. Add `AudioProcessingOptions`, a default value, and a constraint builder that preserves mono/48 kHz/Opus publication settings.
3. Expose an optional active-track constraint method on `VoiceRoom`, implemented with LiveKit's `LocalAudioTrack.applyConstraints`.
4. Run `npm test -- --run frontend/src/voice/livekit_gateway.spec.ts` and confirm it passes.

### Task 2: Carry the preference through voice mute and deafen flows

**Status:** Complete — focused session tests passed.

**Files:**
- Create: `frontend/src/voice/voice_audio_processing.ts`
- Modify: `frontend/src/voice/voice_session.ts`
- Modify: `frontend/src/voice/voice_deafen.ts`
- Test: `frontend/src/voice/voice_session.spec.ts`

1. Write failing session tests proving a changed preference applies to an active track and survives later mute/unmute/deafen restore.
2. Implement the state holder: it updates the active track when the room exposes the supported method, otherwise stores the preference for the next capture.
3. Pass the same preference to all microphone enable operations, including deafen restoration.
4. Run `npm test -- --run frontend/src/voice/voice_session.spec.ts` and confirm it passes.

### Task 3: Expose user controls and record truthful scope

**Status:** Complete — full frontend tests, build, traceability, and whitespace check passed.

**Files:**
- Modify: `frontend/src/voice/audio_settings_store.ts`
- Modify: `frontend/src/workspace/voice_controls.ts`
- Modify: `frontend/src/voice/AudioSettings.vue`
- Modify: `frontend/src/App.vue`
- Modify: `TODO.md`

1. Add failing store/component-facing tests if the current test harness supports the changed boundary.
2. Add three accessible checkboxes that dispatch AGC, echo cancellation, and noise suppression settings through the active voice session.
3. State in TODO that these request browser-native constraints; actual device/browser effectiveness still requires the documented hardware POC and integration evidence.
4. Run the full frontend test suite, build, traceability check, and `git diff --check`.
