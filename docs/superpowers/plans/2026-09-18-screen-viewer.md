# Screen Viewer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a member of a LiveKit voice room list its remote screen shares and play exactly one chosen remote video/audio pair without invisible screen subscriptions.

**Architecture:** The LiveKit adapter joins with `autoSubscribe: false`, explicitly enables microphone publications, and keeps every remote screen publication unsubscribed until selection. `screen_viewer_controller.ts` owns selection order and media attachment; a small Vue viewer receives only card metadata and the one selected video/audio element. The API remains out of the media path.

**Tech Stack:** Vue 3, Pinia, TypeScript, Vitest, LiveKit Client 2.22.3.

---

### Task 1: Test a one-stream selection controller

**Files:**

- Create: `frontend/src/voice/screen_viewer_controller.ts`
- Create: `frontend/src/voice/screen_viewer_controller.spec.ts`

- [ ] **Step 1: Write a failing test for subscription order and detach.**

```ts
await controller.select('stream-b', video, audio)
expect(streamA.video.setSubscribed).toHaveBeenCalledWith(false)
expect(streamA.audio?.setSubscribed).toHaveBeenCalledWith(false)
expect(streamB.video.setSubscribed).toHaveBeenCalledWith(true)
expect(streamB.audio?.setSubscribed).toHaveBeenCalledWith(true)
expect(streamA.video.detach).toHaveBeenCalledWith(video)
```

- [ ] **Step 2: Run the focused test and verify it fails.**

Run: `npm test -- --run src/voice/screen_viewer_controller.spec.ts`

Expected: FAIL because the controller module does not exist.

- [ ] **Step 3: Implement the controller with the required sequence.**

```ts
export class ScreenViewerController {
  async select(streamID: string | null, video: HTMLVideoElement, audio: HTMLAudioElement): Promise<void> {
    this.detachSelected(video, audio)
    this.unsubscribeSelected()
    this.selected = this.streams().find((stream) => stream.id === streamID) ?? null
    if (!this.selected) return
    this.selected.video.setSubscribed(true)
    this.selected.audio?.setSubscribed(true)
    this.attachSelected(video, audio)
  }
}
```

The controller must reject an unknown stream ID, detach before replacing the selection, and leave every unselected screen audio/video publication unsubscribed.

- [ ] **Step 4: Run the focused test and verify it passes.**

Run: `npm test -- --run src/voice/screen_viewer_controller.spec.ts`

Expected: PASS; no test asserts that a second remote screen is attached or subscribed.

### Task 2: Adapt LiveKit room events and preserve remote voice

**Files:**

- Modify: `frontend/src/voice/livekit_gateway.ts`
- Modify: `frontend/src/voice/livekit_gateway.spec.ts`
- Create: `frontend/src/voice/livekit_screen_registry.ts`
- Test: `frontend/src/voice/livekit_screen_registry.spec.ts`

- [ ] **Step 1: Write failing registry tests.**

```ts
registry.refresh([remote('alice', screenVideo, screenAudio), remote('bob', screenVideoB)])
expect(registry.streams()).toEqual([
  { id: 'alice:screen', participantId: 'alice', participantName: 'Alice', hasAudio: true },
  { id: 'bob:screen', participantId: 'bob', participantName: 'Bob', hasAudio: false },
])
expect(screenVideo.setSubscribed).toHaveBeenCalledWith(false)
```

- [ ] **Step 2: Run the registry test and verify it fails.**

Run: `npm test -- --run src/voice/livekit_screen_registry.spec.ts`

Expected: FAIL because the registry module does not exist.

- [ ] **Step 3: Build the registry and bind it in the lazy LiveKit adapter.**

```ts
const liveKitRoom = new Room({ reconnectPolicy: new BoundedVoiceReconnectPolicy() })
await liveKitRoom.connect(url, token, { autoSubscribe: false })
subscribeAllMicrophonePublications(liveKitRoom)
liveKitRoom.on(RoomEvent.TrackPublished, (_, participant) => registry.refresh(liveKitRoom.remoteParticipants))
liveKitRoom.on(RoomEvent.TrackUnpublished, (_, participant) => registry.refresh(liveKitRoom.remoteParticipants))
```

For `Track.Source.ScreenShare` and `Track.Source.ScreenShareAudio`, the registry calls `setSubscribed(false)` until controller selection. For `Track.Source.Microphone`, it calls `setSubscribed(true)` so disabling automatic subscription does not mute normal room voice. The adapter reports only remote participants already admitted by the room-scoped token.

- [ ] **Step 4: Run focused SDK/registry tests and production type-check.**

Run: `npm test -- --run src/voice/livekit_gateway.spec.ts src/voice/livekit_screen_registry.spec.ts; npm run build`

Expected: PASS; no SDK token, room-admin grant, media payload or server proxy is introduced.

### Task 3: Bind the selected remote stream to the voice view

**Files:**

- Create: `frontend/src/voice/screen_viewer_controls.ts`
- Create: `frontend/src/voice/ScreenViewer.vue`
- Modify: `frontend/src/voice/voice_session.ts`
- Modify: `frontend/src/voice/connection_store.ts`
- Modify: `frontend/src/conversation/ConversationPane.vue`
- Modify: `frontend/src/App.vue`

- [ ] **Step 1: Write a failing controls test for removal and explicit clear.**

```ts
controls.start()
await controls.select('alice:screen', video, audio)
source.remove('alice:screen')
source.notify()
expect(selected.value).toBeNull()
expect(source.select).toHaveBeenLastCalledWith(null, video, audio)
```

- [ ] **Step 2: Run the controls test and verify it fails.**

Run: `npm test -- --run src/voice/screen_viewer_controls.spec.ts`

Expected: FAIL because controls do not exist.

- [ ] **Step 3: Implement metadata-only cards and one selected player.**

```vue
<button v-for="stream in streams" :key="stream.id" type="button" @click="select(stream.id)">
  {{ stream.participantName }} <span>{{ stream.hasAudio ? 'со звуком' : 'без аудио' }}</span>
</button>
<video v-if="selected" ref="video" autoplay playsinline></video>
<audio v-if="selected" ref="audio" autoplay></audio>
```

The card list never attaches media. Selection passes the only rendered `video`/`audio` nodes to the controller. On stream removal, unmount, voice leave or unrecoverable disconnect, controls select `null` to detach and unsubscribe the old tracks; the UI shows a placeholder and never auto-selects another stream.

- [ ] **Step 4: Run frontend checks.**

Run: `npm test -- --run; npm run build`

Expected: PASS; a LiveKit lazy chunk size warning is non-fatal but must not be described as an optimization result.

### Task 4: Record scope and verify the route

**Files:**

- Modify: `TODO.md`
- Modify: `docs/API_AND_REALTIME.md`

- [ ] **Step 1: Document implemented subscription semantics.**

State that only a current voice-room participant sees available remote stream metadata; selected remote screen media is the single client-side subscription. State that unit tests do not verify media, screen audio, cross-browser handling, p95 switching or POC evidence.

- [ ] **Step 2: Run product checks and inspect worktree.**

Run: `powershell -ExecutionPolicy Bypass -File scripts/verify-spec-traceability.ps1; git diff --check; git status --short`

Expected: traceability passes, whitespace check has no error, and no generated evidence is reported as POC completion.

**Coverage review:** This plan covers the selected-viewer portions of REQ-SCREEN-03 and REQ-CAPACITY-02: no product quota, no hidden selected-screen subscription, one selected stream audio/video pair, prior stream removal before switch, and a stopped-stream placeholder. It does not prove POC-01/02 hardware capture, p95 switching, capacity or SFU enforcement; each still needs real evidence.

**Execution note:** Execute inline in the existing shared dirty worktree. Do not stage or commit unrelated files.
