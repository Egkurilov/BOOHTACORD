# Listener-Only Voice Join Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user join a voice room without requesting or publishing microphone audio, while preserving the existing microphone-enabled join as the default.

**Architecture:** Carry a typed join mode from the pre-join UI through the workspace and voice store/session to the LiveKit gateway. The listener path connects to LiveKit and starts normal remote playback/subscriptions but never calls `setMicrophoneEnabled`; the existing path remains unchanged. Extract the voice-session contracts into a type-only file so the edited session module meets the repository's 120-line hard ratchet.

**Tech Stack:** Vue 3, TypeScript, Pinia, LiveKit Client, Vitest, Vite.

---

### Task 1: Lock the no-publication boundary with a failing test

**Files:**
- Create: `frontend/src/voice/listener_only_join.spec.ts`
- Test: `frontend/src/voice/listener_only_join.spec.ts`

- [ ] **Step 1: Assert listener join connects the room without touching the local microphone.**

Use a fake room whose `connect`, `disconnect`, and `localParticipant.setMicrophoneEnabled` are Vitest spies. Call `connectLiveKitRoom(credential, () => room, undefined, undefined, 'listener')`; expect `microphone: 'MUTED'`, one room connection with `autoSubscribe: false`, and zero calls to `setMicrophoneEnabled`.

- [ ] **Step 2: Assert the voice session forwards listener mode.**

Construct `VoiceSession` with an admission stub and a room-joiner spy. Call `session.join('voice-1', false, 'listener')`; expect the room-joiner to receive the credential, processing preferences, and `'listener'`, and the active session to retain `microphone: 'MUTED'`.

- [ ] **Step 3: Run the new test and verify it fails before implementation.**

Run: `npm test -- src/voice/listener_only_join.spec.ts`

Expected: FAIL because the gateway and session do not yet accept a join mode.

### Task 2: Implement listener-only LiveKit connection

**Files:**
- Modify: `frontend/src/voice/livekit_gateway.ts`
- Create: `frontend/src/voice/voice_session_types.ts`
- Modify: `frontend/src/voice/voice_session.ts`

- [ ] **Step 1: Define the mode and type-only voice-session contracts.**

Export `VoiceJoinMode = 'with-microphone' | 'listener'` from `livekit_gateway.ts`. Move `VoiceAdmission`, `ActiveVoiceSession`, `RoomJoiner`, and `VoiceConnectionObserver` into `voice_session_types.ts`; keep the existing type exports from `voice_session.ts` so callers remain source-compatible. `RoomJoiner` accepts an optional third `VoiceJoinMode` argument.

- [ ] **Step 2: Preserve the default and skip microphone acquisition only for listener mode.**

Keep `connectLiveKitRoom` defaulting to `'with-microphone'`. After `room.connect` succeeds, return `{ room, microphone: 'MUTED' }` immediately for `'listener'`; otherwise execute the existing `setMicrophone(room, true, processing)` flow and retain its timeout/error cleanup.

- [ ] **Step 3: Carry join mode through `VoiceSession.join`.**

Add an optional third mode argument defaulting to `'with-microphone'`; pass it to `RoomJoiner`. Keep lease acquisition, release-on-failure, session binding, and reconnection behavior unchanged. Confirm `voice_session.ts` is at most 120 lines after extracting its contracts.

- [ ] **Step 4: Run gateway and session tests.**

Run: `npm test -- src/voice/listener_only_join.spec.ts src/voice/livekit_gateway.spec.ts src/voice/voice_session.spec.ts`

Expected: PASS; existing default join still publishes the microphone and listener join never requests it.

### Task 3: Carry listener mode through the client and expose it before joining

**Files:**
- Modify: `frontend/src/voice/connection_store.ts`
- Modify: `frontend/src/voice/connection_store.spec.ts`
- Modify: `frontend/src/workspace/voice_controls.ts`
- Modify: `frontend/src/conversation/ConversationPane.vue`
- Modify: `frontend/src/workspace/WorkspaceMain.vue`

- [ ] **Step 1: Test store state after listener join.**

Extend the store test with a `session.join` spy; call `store.join('voice-1', false, 'listener')`. Expect forwarding of `'listener'`, `microphoneMuted === true`, and `state === 'LISTENER'` when the session result reports `microphone: 'MUTED'`.

- [ ] **Step 2: Thread the optional mode through existing join controls.**

Add an optional third `VoiceJoinMode` argument to `connection_store.join` and `joinVoice`, defaulting to `'with-microphone'`. Pass it unchanged through to the session; keep transfer confirmation and audio-processing setup intact.

- [ ] **Step 3: Add a secondary pre-join action and preserve the primary action.**

Extend the `ConversationPane` `join` event with optional transfer and mode arguments. Leave the existing “Подключиться к голосу” click unchanged; add one secondary button “Подключиться без микрофона” that emits `join(channel.id, false, 'listener')`. Keep both buttons disabled while `voiceState === 'JOINING'`. Bind the same event directly to `joinVoice` in `WorkspaceMain`.

- [ ] **Step 4: Run the focused store test and type-check.**

Run: `npm test -- src/voice/connection_store.spec.ts src/voice/listener_only_join.spec.ts`; then `npm run build`.

Expected: PASS; listener state shows the microphone muted, normal join behavior and transfer remain unchanged, and Vue/TypeScript accepts the event signature.

### Task 4: Full frontend verification and closeout

**Files:**
- Verify: all files above
- Update: this plan's checkboxes

- [ ] **Step 1: Run the full frontend suite and production build.**

Run: `npm test`; then `npm run build`.

Expected: all frontend tests PASS and Vite produces the web artifact; record any existing chunk-size warning separately from failures.

- [ ] **Step 2: Inspect diff, limits, and whitespace.**

Run `git status --short`, inspect only the listed implementation files, check each modified production/test file is at most 120 lines, and run `git diff --check`. Do not stage unrelated dirty work, deploy, or claim production verification from local tests.

**Product diff:** A user can explicitly join as a listener without invoking microphone capture or publishing an audio track. The existing primary join keeps its current microphone-enabled behavior.

**Out of scope:** This does not prove Windows/macOS physical POC, connected production visual parity, or the separate reference conflict between the PNG's lower leave bar and C-18.
