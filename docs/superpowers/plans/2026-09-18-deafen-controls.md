# Deafen Controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make deafen silence every locally attached remote audio track, force microphone mute, and restore the pre-deafen microphone state without stopping a local screen publication.

**Architecture:** A dedicated remote-voice playback adapter owns the browser audio elements for room microphone tracks; it can mute and detach them without exposing media to Go. The existing selected screen controller also mutes its one audio element. `VoiceSession` owns the pre-deafen microphone state; Pinia exposes an explicit, race-safe UI state.

**Tech Stack:** Vue 3, Pinia, TypeScript, Vitest, LiveKit Client 2.22.3.

---

### Task 1: Manage attached remote microphone playback

**Files:**

- Create: `frontend/src/voice/remote_voice_playback.ts`
- Create: `frontend/src/voice/remote_voice_playback.spec.ts`
- Modify: `frontend/src/voice/livekit_screen_viewer_adapter.ts`

- [ ] **Step 1: Write a failing playback test.**

```ts
playback.attach('alice', track)
playback.setDeafened(true)
expect(element.muted).toBe(true)
playback.detach('alice')
expect(track.detach).toHaveBeenCalledWith(element)
expect(element.remove).toHaveBeenCalledOnce()
```

- [ ] **Step 2: Run the focused test and verify it fails.**

Run: `npm test -- --run src/voice/remote_voice_playback.spec.ts`

Expected: FAIL because the playback module does not exist.

- [ ] **Step 3: Implement a DOM-element owner with injected element factory.**

```ts
export class RemoteVoicePlayback {
  setDeafened(deafened: boolean): void { /* update all attached elements and future ones */ }
  attach(id: string, track: RemoteAudioTrack): void { /* detach previous ID, attach one audio element */ }
  detach(id: string): void { /* detach SDK track and remove the owned element */ }
  clear(): void { /* detach every owned microphone element */ }
}
```

The adapter attaches only microphone tracks. It does not attach remote screen audio, which remains owned by the selected-screen viewer.

- [ ] **Step 4: Extend the LiveKit adapter events.**

```ts
room.on(events.trackSubscribed, (track, publication, participant) => {
  if (publication.source === sources.microphone) playback.attach(participant.identity, track)
  refresh()
})
room.on(events.trackUnsubscribed, (_, publication, participant) => {
  if (publication.source === sources.microphone) playback.detach(participant.identity)
  refresh()
})
```

Expose `setDeafened` and `clear` through the binding; track IDs stay client-local and are never logged.

- [ ] **Step 5: Run focused tests.**

Run: `npm test -- --run src/voice/remote_voice_playback.spec.ts src/voice/livekit_screen_viewer_adapter.spec.ts`

Expected: PASS; no selected or unselected remote screen audio is attached by this playback adapter.

### Task 2: Preserve microphone state around deafen

**Files:**

- Modify: `frontend/src/voice/livekit_gateway.ts`
- Modify: `frontend/src/voice/screen_viewer_controller.ts`
- Modify: `frontend/src/voice/voice_session.ts`
- Modify: `frontend/src/voice/voice_session.spec.ts`

- [ ] **Step 1: Write failing session tests.**

```ts
await session.setDeafened(true)
expect(room.setDeafened).toHaveBeenCalledWith(true)
expect(room.localParticipant.setMicrophoneEnabled).toHaveBeenCalledWith(false, expect.anything(), expect.anything())
await session.setDeafened(false)
expect(room.setDeafened).toHaveBeenLastCalledWith(false)
expect(room.localParticipant.setMicrophoneEnabled).toHaveBeenLastCalledWith(true, expect.anything(), expect.anything())
```

The same test includes an initially-muted participant and asserts that undeafen does not enable their microphone.

- [ ] **Step 2: Run the focused test and verify it fails.**

Run: `npm test -- --run src/voice/voice_session.spec.ts`

Expected: FAIL because `setDeafened` does not exist.

- [ ] **Step 3: Add the explicit media boundary.**

```ts
async setDeafened(deafened: boolean): Promise<MicrophoneState> {
  const current = this.requireCurrent()
  if (deafened) {
    this.microphoneBeforeDeafen = current.microphone
    if (current.microphone === 'PUBLISHED') current.microphone = await setMicrophone(current.room, false)
    current.room.setDeafened?.(true)
    return current.microphone
  }
  current.room.setDeafened?.(false)
  if (this.microphoneBeforeDeafen === 'PUBLISHED') current.microphone = await setMicrophone(current.room, true)
  this.microphoneBeforeDeafen = null
  return current.microphone
}
```

`ScreenViewerController.setDeafened` sets the selected audio element's `muted` flag and remembers it for a later selected screen. The default LiveKit room binding forwards one deafen flag to both remote microphone playback and this selected screen element, then clears media on `disconnect`.

- [ ] **Step 4: Run focused session/controller tests.**

Run: `npm test -- --run src/voice/voice_session.spec.ts src/voice/screen_viewer_controller.spec.ts`

Expected: PASS; a screen publication is not stopped or disabled by deafen.

### Task 3: Expose and document the voice state

**Files:**

- Modify: `frontend/src/voice/connection_store.ts`
- Modify: `frontend/src/voice/VoiceDock.vue`
- Modify: `frontend/src/App.vue`
- Modify: `TODO.md`
- Modify: `docs/API_AND_REALTIME.md`

- [x] **Step 1: Wire a `deafened` state and control.**

```vue
<button type="button" @click="emit('toggleDeafen')">
  {{ deafened ? 'Включить звук' : 'Отключить звук' }}
</button>
<p v-if="deafened">Удалённый звук отключён; ваш экран при этом может продолжать передаваться.</p>
```

Disable microphone toggles while deafen is transitioning or active. When PTT invokes an attempted microphone change, the existing connection store returns without enabling it while deafened.

- [x] **Step 2: Run all frontend checks and requirement traceability.**

Run: `npm test -- --run; npm run build; powershell -ExecutionPolicy Bypass -File scripts/verify-spec-traceability.ps1; git diff --check`

Expected: PASS; browser/LiveKit hardware behaviour, screen/game audio and capacity remain unproven.

**Coverage review:** The plan implements the deafen portion of REQ-VOICE-01: all attached remote media is silenced, microphone state is preserved, and local screen publishing remains independent. It intentionally does not implement per-participant 0–200% volume persistence, output-device changes under deafen, speaking indicators, POC or media performance measurements.

**Execution note:** Execute inline in the shared dirty worktree; do not stage, commit, or delete unrelated files.
