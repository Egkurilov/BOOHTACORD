# Speaking Indicator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to execute this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show an accessible, current-room speaking state for every locally attached remote microphone participant without sending media or participant telemetry through Go.

**Architecture:** The existing LiveKit binding consumes `RoomEvent.ActiveSpeakersChanged`, intersects its list with current `remoteParticipants`, and writes boolean state into the room-owned remote voice playback controller. Playback retains state for a temporarily unsubscribed track and destroys it when the participant leaves. The volume card consumes that controller state and renders both a text label and visual dot.

**Tech Stack:** Vue 3, TypeScript, LiveKit Client, Vitest.

---

### Task 1: Model and clean up remote speaking state

**Files:**

- Modify: `frontend/src/voice/remote_voice_playback.ts`
- Modify: `frontend/src/voice/remote_voice_playback.spec.ts`

- [x] **Step 1: Write a failing playback behavior test.**

```ts
playback.setSpeaking('alice', true)
playback.attach('alice', track)
expect(playback.cards()).toEqual([expect.objectContaining({ id: 'alice', speaking: true })])
playback.forget('alice')
expect(playback.cards()).toEqual([])
```

- [x] **Step 2: Run the focused test.**

Run: `npm test -- --run src/voice/remote_voice_playback.spec.ts`

Expected: FAIL because the controller has neither a speaking state nor participant cleanup API.

- [x] **Step 3: Implement the room-owned state.**

Add `speaking: boolean` to `RemoteVoiceCard`, a `setSpeaking(participantID, speaking)` method, and `forget(participantID)`. `attach` applies pending state; `forget` removes speaking/volume state and owned audio. Notify observers only when an attached card changes.

- [x] **Step 4: Re-run the focused test.**

Run: `npm test -- --run src/voice/remote_voice_playback.spec.ts`

Expected: PASS.

### Task 2: Bind only authoritative LiveKit speaking events

**Files:**

- Modify: `frontend/src/voice/livekit_screen_viewer_adapter.ts`
- Modify: `frontend/src/voice/livekit_screen_viewer_adapter.spec.ts`
- Modify: `frontend/src/voice/livekit_gateway.ts`

- [x] **Step 1: Add a failing adapter test for `active-speakers-changed`.**

```ts
listeners.get('active-speakers-changed')!([alice])
expect(playback.setSpeaking).toHaveBeenCalledWith('account-id', true)
expect(playback.setSpeaking).toHaveBeenCalledWith('other-account-id', false)
```

- [x] **Step 2: Run the adapter test.**

Run: `npm test -- --run src/voice/livekit_screen_viewer_adapter.spec.ts`

Expected: FAIL because the event is not part of the adapter event contract.

- [x] **Step 3: Wire the event and leave path.**

Add `activeSpeakersChanged` from `RoomEvent.ActiveSpeakersChanged`. On every event, derive the set of stable participant IDs and set speaking only for `room.remoteParticipants`; the local participant is never represented. On participant disconnect call `forget`, not only audio detach, so memory does not grow across departures.

- [x] **Step 4: Re-run focused adapter tests.**

Run: `npm test -- --run src/voice/livekit_screen_viewer_adapter.spec.ts src/voice/remote_voice_playback.spec.ts`

Expected: PASS.

### Task 3: Render accessible participant state and update scope records

**Files:**

- Modify: `frontend/src/voice/VoiceParticipantVolumes.vue`
- Modify: `frontend/src/style.css`
- Modify: `TODO.md`
- Modify: `docs/API_AND_REALTIME.md`
- Modify: `docs/superpowers/plans/2026-09-18-speaking-indicator.md`

- [x] **Step 1: Add the text-plus-dot indicator.**

```vue
<span class="participant-speaking" :class="{ active: participant.speaking }">
  {{ participant.speaking ? 'Говорит' : 'Не говорит' }}
</span>
```

The label remains visible without colour. It identifies the current LiveKit room state, not microphone permission, input level, voice activity threshold or a server-side moderation fact.

- [x] **Step 2: Verify production compilation and the full frontend suite.**

Run: `npm test -- --run; npm run build; powershell -ExecutionPolicy Bypass -File scripts/verify-spec-traceability.ps1; git diff --check`

Expected: PASS. Real LiveKit/browser speaking behavior, audio measurement and POC evidence remain open.

**Coverage review:** This packet fills the speaking-indicator control named by REQ-VOICE-01 and the non-colour UI requirement. It does not validate speaker detection performance or actual media behavior; those need browser/LiveKit and hardware evidence.

**Execution note:** Execute inline in the shared dirty worktree. Do not stage, commit or alter unrelated changes.
