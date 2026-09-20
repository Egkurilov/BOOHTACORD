# Audio Processing Diagnostics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a connected user the browser-reported state of AGC, echo cancellation, and noise suppression alongside their requested settings.

**Architecture:** A pure diagnostic leaf translates browser `MediaTrackSettings` into a three-state result and retains the requested boolean separately. The LiveKit room adapter reads `LocalAudioTrack.mediaStreamTrack.getSettings()` when a microphone exists; the session and Pinia connection state refresh this observation after joining or changing a constraint, and the audio settings UI renders the two facts distinctly.

**Tech Stack:** Vue 3, Pinia, TypeScript, Vitest, browser MediaStreamTrack, LiveKit JS 2.22.3.

---

### Task 1: Normalize browser-reported microphone settings

**Status:** Complete — pure diagnostic tests pass.

**Files:**
- Create: `frontend/src/voice/audio_processing_diagnostics.ts`
- Create: `frontend/src/voice/audio_processing_diagnostics.spec.ts`

- [x] **Step 1: Write the failing normalization tests**

```ts
const requested = { autoGainControl: true, echoCancellation: false, noiseSuppression: true }
expect(describeAudioProcessing(requested, { autoGainControl: true, echoCancellation: false })).toEqual({
  autoGainControl: { requested: true, reported: 'ENABLED' },
  echoCancellation: { requested: false, reported: 'DISABLED' },
  noiseSuppression: { requested: true, reported: 'UNAVAILABLE' },
})
```

- [x] **Step 2: Run the diagnostic test to verify it fails**

Run: `npm test -- --run src/voice/audio_processing_diagnostics.spec.ts`

Expected: FAIL because `describeAudioProcessing` does not exist.

- [x] **Step 3: Implement the pure diagnostic model**

```ts
export type AudioProcessingReport = 'ENABLED' | 'DISABLED' | 'UNAVAILABLE'
export interface BrowserAudioProcessingSettings {
  autoGainControl?: boolean
  echoCancellation?: boolean
  noiseSuppression?: boolean
}
export interface AudioProcessingDiagnostics {
  autoGainControl: { requested: boolean; reported: AudioProcessingReport }
  echoCancellation: { requested: boolean; reported: AudioProcessingReport }
  noiseSuppression: { requested: boolean; reported: AudioProcessingReport }
}
export function describeAudioProcessing(requested: AudioProcessingOptions, settings?: BrowserAudioProcessingSettings): AudioProcessingDiagnostics {
  const reported = (value: boolean | undefined): AudioProcessingReport => value === undefined ? 'UNAVAILABLE' : value ? 'ENABLED' : 'DISABLED'
  return {
    autoGainControl: { requested: requested.autoGainControl, reported: reported(settings?.autoGainControl) },
    echoCancellation: { requested: requested.echoCancellation, reported: reported(settings?.echoCancellation) },
    noiseSuppression: { requested: requested.noiseSuppression, reported: reported(settings?.noiseSuppression) },
  }
}
```

- [x] **Step 4: Run the diagnostic test to verify it passes**

Run: `npm test -- --run src/voice/audio_processing_diagnostics.spec.ts`

Expected: PASS with enabled, disabled, and unavailable values covered.

### Task 2: Read observable settings from the local LiveKit microphone

**Status:** Complete — session diagnostic test passes.

**Files:**
- Modify: `frontend/src/voice/livekit_gateway.ts`
- Modify: `frontend/src/voice/voice_audio_processing.ts`
- Create: `frontend/src/voice/voice_audio_processing.spec.ts`

- [x] **Step 1: Write the failing session diagnostic test**

```ts
const room = { readAudioProcessingSettings: () => ({ autoGainControl: false, echoCancellation: true, noiseSuppression: false }) }
const processing = new VoiceAudioProcessing(() => ({ room: room as VoiceRoom }))
await processing.set({ autoGainControl: true, echoCancellation: false, noiseSuppression: true })
expect(processing.diagnostics.echoCancellation).toEqual({ requested: false, reported: 'ENABLED' })
```

- [x] **Step 2: Run the session diagnostic test to verify it fails**

Run: `npm test -- --run src/voice/voice_audio_processing.spec.ts`

Expected: FAIL because `diagnostics` and `readAudioProcessingSettings` do not exist.

- [x] **Step 3: Add the LiveKit adapter edge and session accessor**

```ts
room.readAudioProcessingSettings = () => {
  const track = liveKitRoom.localParticipant.getTrackPublication(Track.Source.Microphone)?.audioTrack
  return track?.mediaStreamTrack.getSettings()
}
get diagnostics(): AudioProcessingDiagnostics {
  return describeAudioProcessing(this.options, this.current()?.room.readAudioProcessingSettings?.())
}
```

- [x] **Step 4: Run the session diagnostic test to verify it passes**

Run: `npm test -- --run src/voice/voice_audio_processing.spec.ts`

Expected: PASS with requested and browser-reported values shown independently.

### Task 3: Refresh and render diagnostics in voice settings

**Status:** Complete — UI receives a refreshed snapshot after every relevant voice-state transition.

**Files:**
- Modify: `frontend/src/voice/connection_store.ts`
- Modify: `frontend/src/voice/AudioSettings.vue`
- Modify: `frontend/src/App.vue`
- Modify: `TODO.md`

- [x] **Step 1: Write a failing UI-facing diagnostic text test**

```ts
expect(audioProcessingStatus({ requested: true, reported: 'UNAVAILABLE' })).toBe('Запрошено: включено; браузер не сообщил состояние.')
```

- [x] **Step 2: Run the text test to verify it fails**

Run: `npm test -- --run src/voice/audio_processing_diagnostics.spec.ts`

Expected: FAIL because `audioProcessingStatus` does not exist.

- [x] **Step 3: Refresh diagnostics after join and constraint changes, then render each value**

```ts
const audioProcessingDiagnostics = ref(session.audioProcessing.diagnostics)
function refreshAudioProcessingDiagnostics(): void { audioProcessingDiagnostics.value = session.audioProcessing.diagnostics }
async function setAudioProcessing(options: AudioProcessingOptions): Promise<void> {
  await session.setAudioProcessing(options)
  refreshAudioProcessingDiagnostics()
}
export function audioProcessingStatus(diagnostic: { requested: boolean; reported: AudioProcessingReport }): string {
  const requested = diagnostic.requested ? 'включено' : 'выключено'
  if (diagnostic.reported === 'UNAVAILABLE') return `Запрошено: ${requested}; браузер не сообщил состояние.`
  return `Запрошено: ${requested}; браузер сообщает: ${diagnostic.reported === 'ENABLED' ? 'включено' : 'выключено'}.`
}
```

- [x] **Step 4: State the diagnostic evidence boundary in TODO**

```md
The UI reports only browser `getSettings()` output. `UNAVAILABLE` means the browser did not expose a value; it does not prove unsupported processing or degraded audio quality.
```

- [x] **Step 5: Run native checks**

Run: `npm test -- --run`, `npm run build`, `scripts/verify-spec-traceability.ps1`, and `git diff --check`.

Expected: all tests and build pass; traceability reports all requirements.

## Self-review

Coverage: Task 1 supplies stable representation, Task 2 connects it to a published microphone, and Task 3 renders it without treating missing settings as proof of an unsupported feature. Browser/hardware effectiveness remains an integration-evidence item rather than a UI claim.

Type consistency: `AudioProcessingOptions` remains the request type, `BrowserAudioProcessingSettings` represents only observed browser data, and `AudioProcessingDiagnostics` exposes both values to UI code.
