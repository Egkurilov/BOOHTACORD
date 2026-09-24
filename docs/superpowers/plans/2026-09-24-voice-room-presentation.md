# Voice Room Presentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make voice members and their speaking/microphone state immediately legible, and let the screen viewer expand across the channel workspace without hiding the voice roster.

**Architecture:** Keep participant state sourced from LiveKit and render it through the existing voice status components. Subscribe to LiveKit mute/unmute events so the roster refreshes immediately. Add a workspace-fill viewer mode owned by `ConversationPane`, while retaining the existing browser fullscreen control for monitor-wide viewing.

**Tech Stack:** Vue 3, TypeScript, LiveKit Client, Vitest, Vite.

---

## Scope and route

- Slavik Gym route: `split_first`; selected leaf: `frontend/src/voice/voice-room-presentation` under backlog task T-050.
- Entry path: `WorkspaceApp.vue` → `WorkspaceMain.vue` → `ConversationPane.vue` → `ScreenViewer.vue` and `VoiceParticipantStrip.vue`.
- Live participant state path: LiveKit room events → `livekit_screen_viewer_adapter.ts` → `connection_store.ts` → member and screen-viewer UI.
- Preserve current server, authentication, voice admission, screen publication, and native browser fullscreen behavior.
- Exclude production deployment, backend/API changes, schema changes, hardware POC claims, and pixel-review screenshots.

## Files

- Modify `frontend/src/voice/livekit_screen_viewer_adapter.ts` to refresh participant cards on remote microphone mute/unmute events.
- Modify `frontend/src/voice/livekit_room_factory.ts` to bind the pinned LiveKit SDK event constants.
- Test the LiveKit refresh path in `frontend/src/voice/livekit_screen_viewer_adapter.spec.ts`.
- Modify `frontend/src/workspace/WorkspaceMembersPanel.vue` to show readable state labels alongside the existing microphone/speaking icon.
- Modify `frontend/src/voice/ScreenViewer.vue` and `frontend/src/conversation/ConversationPane.vue` to expose and own the workspace-fill mode, including Escape-to-exit.
- Modify `frontend/src/design/voice.css` for the expanded stage, roster, and readable status layout.
- Extend `frontend/src/voice/voice_room_presentation.spec.ts` for visible labels, the workspace-fill action, and roster retention.

## Tasks

### Task 1: Pin down live mute updates and visible room states

**Files:**
- Test: `frontend/src/voice/livekit_screen_viewer_adapter.spec.ts`
- Test: `frontend/src/voice/voice_room_presentation.spec.ts`

- [x] Add a test that emits `track-muted` and `track-unmuted` for a microphone publication and verifies the participant card changes from `microphoneMuted: false` to `true` and back.
- [x] Add presentation assertions that member rows render readable speaking/muted labels and that the channel-workspace expansion control retains the participant strip.
- [x] Run the focused Vitest tests from `frontend` and confirm the new assertions fail before implementation.

### Task 2: Refresh LiveKit microphone state as it changes

**Files:**
- Modify: `frontend/src/voice/livekit_screen_viewer_adapter.ts`
- Modify: `frontend/src/voice/livekit_room_factory.ts`
- Test: `frontend/src/voice/livekit_screen_viewer_adapter.spec.ts`

- [x] Add `trackMuted` and `trackUnmuted` event ports to `LiveKitScreenViewerEvents`.
- [x] In the adapter, refresh participant cards only when the changed publication is the microphone source.
- [x] Bind `RoomEvent.TrackMuted` and `RoomEvent.TrackUnmuted` in the default room factory.
- [x] Rerun the adapter test and confirm muting/unmuting updates the card immediately without waiting for a speaker event.

### Task 3: Make member state readable without relying on color

**Files:**
- Modify: `frontend/src/workspace/WorkspaceMembersPanel.vue`
- Modify: `frontend/src/design/voice.css`
- Test: `frontend/src/voice/voice_room_presentation.spec.ts`

- [x] Render a short visible state below each member name: `Говорит`, `Микрофон выключен`, `Микрофон недоступен`, or `В голосе`.
- [x] Keep the existing accessible microphone/speaking icon and green speaking outline; allow state text to ellipsize safely in the compact member column.
- [x] Keep self and other participant status visible even when volume-preference loading reports a non-fatal error.
- [x] Rerun `voice_room_presentation.spec.ts` and verify muted and speaking labels are present in the member template.

### Task 4: Expand screen viewing across the channel workspace

**Files:**
- Modify: `frontend/src/voice/ScreenViewer.vue`
- Modify: `frontend/src/conversation/ConversationPane.vue`
- Modify: `frontend/src/design/voice.css`
- Test: `frontend/src/voice/voice_room_presentation.spec.ts`

- [x] Add an explicit button that toggles `Развернуть на всю область` / `Вернуть в окно канала` and binds `aria-pressed` to the current mode.
- [x] Let `ConversationPane` own the expanded state and apply a `voice-room--screen-expanded` class; on Escape and viewer teardown, return to the normal layout.
- [x] In expanded mode, hide the channel header, let the video stage take the available channel-workspace height, and keep the participant strip (including self microphone status) visible; leave the existing native fullscreen action unchanged.
- [x] Rerun the presentation test and check both normal and expanded-state hooks.

### Task 5: Validate the web frontend

**Files:**
- Validation only: changed frontend leaves.

- [x] Run the focused Vitest tests for the adapter and room presentation.
- [x] Run `npm test` from `frontend` (62 files, 178 tests).
- [x] Run `npm run build` from `frontend`; TypeScript and Vite completed successfully.
- [x] Leave T-050 and physical Windows/macOS POC evidence open; these changes do not prove screenshot parity or media POC acceptance.
