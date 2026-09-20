# Remote Participant Cards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to execute this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render an accessible card for every remote participant in the current LiveKit room, including their trustworthy microphone publication state, speaking state and persistent local volume control.

**Architecture:** A dedicated `RemoteParticipantController` derives cards from the room's remote participant map and the room-owned audio playback state. It sees only `RemoteTrackPublication.isMuted` for remote microphone state and never fabricates another user's deafen state. Existing volume controls switch their source from attached audio tracks to these cards, while retaining output control in `RemoteVoicePlayback`.

**Tech Stack:** Vue 3, TypeScript, LiveKit Client, Pinia, Vitest.

---

### Task 1: Build a remote participant controller with truthful state

**Files:**

- Create: `frontend/src/voice/remote_participant_controller.ts`
- Create: `frontend/src/voice/remote_participant_controller.spec.ts`
- Modify: `frontend/src/voice/remote_voice_playback.ts`

- [x] **Step 1: Write a failing controller test.**

```ts
controller.refresh()
expect(controller.cards()).toEqual([{ accountId: 'account-a', id: 'account-a', microphoneMuted: true, name: 'Alice', speaking: false }])
playback.setSpeaking('account-a', true)
expect(cardsChanged).toHaveBeenCalled()
```

- [x] **Step 2: Run the focused test.**

Run: `npm test -- --run src/voice/remote_participant_controller.spec.ts`

Expected: FAIL because there is no controller or `isSpeaking` query.

- [x] **Step 3: Add a pure controller and query edge.**

```ts
export interface RemoteParticipantCard { accountId: string | null; id: string; microphoneMuted: boolean; name?: string; speaking: boolean }
export class RemoteParticipantController {
  refresh(): void { /* map current remote participants; microphone is muted if no publication or publication.isMuted */ }
}
```

`RemoteVoicePlayback.isSpeaking(id)` returns pending or attached state without exposing an audio element. The controller observes playback changes, so a speaking event refreshes cards even when the membership map itself is unchanged.

- [x] **Step 4: Re-run focused tests.**

Run: `npm test -- --run src/voice/remote_participant_controller.spec.ts src/voice/remote_voice_playback.spec.ts`

Expected: PASS.

### Task 2: Bind cards to LiveKit lifecycle and volume controls

**Files:**

- Modify: `frontend/src/voice/livekit_screen_viewer_adapter.ts`
- Modify: `frontend/src/voice/livekit_screen_viewer_adapter.spec.ts`
- Modify: `frontend/src/voice/livekit_gateway.ts`
- Modify: `frontend/src/voice/voice_session.ts`
- Modify: `frontend/src/voice/voice_session.spec.ts`
- Modify: `frontend/src/voice/voice_volume_controls.ts`
- Modify: `frontend/src/voice/voice_volume_controls.spec.ts`

- [x] **Step 1: Write failing adapter/control tests.**

```ts
binding.refresh()
expect(binding.participants.cards()).toEqual([expect.objectContaining({ microphoneMuted: true })])
await controls.start()
expect(controls.participants.value).toEqual([expect.objectContaining({ id: 'account-a', volume: 100 })])
```

- [x] **Step 2: Implement native lifecycle edges.**

Create the controller once with a source that maps only `room.remoteParticipants`, normalized signed account ID and `getTrackPublication(microphone)`. Call `participants.refresh()` wherever the adapter refreshes. Expose it through `VoiceRoom` and `VoiceSession`. `VoiceVolumeControls` subscribes to participant cards but calls `remoteVoices.setVolume`; cards without signed `accountId` retain display state but expose no persistent slider.

- [x] **Step 3: Run focused adapter/session/control tests.**

Run: `npm test -- --run src/voice/livekit_screen_viewer_adapter.spec.ts src/voice/voice_session.spec.ts src/voice/voice_volume_controls.spec.ts`

Expected: PASS.

### Task 3: Render explicit remote microphone state

**Files:**

- Modify: `frontend/src/voice/VoiceParticipantVolumes.vue`
- Modify: `frontend/src/style.css`
- Modify: `TODO.md`
- Modify: `docs/API_AND_REALTIME.md`
- Modify: `docs/superpowers/plans/2026-09-18-remote-participants.md`

- [x] **Step 1: Replace the attached-audio empty state with all-room participant cards.**

```vue
<span class="participant-microphone" :class="{ muted: participant.microphoneMuted }">
  {{ participant.microphoneMuted ? 'Микрофон выключен' : 'Микрофон включён' }}
</span>
```

The remote microphone label and speaking label must both be visible without colour. Keep local deafen only in the local voice dock; the UI must not claim it can inspect another user's deafen state.

- [x] **Step 2: Run native frontend verification.**

Run: `npm test -- --run; npm run build; powershell -ExecutionPolicy Bypass -File scripts/verify-spec-traceability.ps1; git diff --check`

Expected: PASS. Browser/LiveKit integration, unknown participant-name policy and POC evidence remain open.

**Coverage review:** This leaf completes the participant-card statuses named in UI_SPEC using observable remote media state. It does not prove LiveKit publication events, microphone mute propagation, audio quality or remote deafen behavior without real integration evidence.

**Execution note:** Execute inline in the shared dirty worktree. Do not stage, commit or alter unrelated changes.
