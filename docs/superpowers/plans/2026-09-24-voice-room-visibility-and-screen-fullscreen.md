# Voice Room Visibility and Screen Fullscreen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use inline execution with task-by-task validation. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep live voice participants and their microphone/speaking state visible while a screen is being watched, and let the viewer expand the stage to the browser's fullscreen viewport.

**Architecture:** Reuse the existing LiveKit-derived `VoiceVolumeParticipant` state; add small presentation-only status and roster components without new API calls or guessed users. Keep fullscreen browser effects behind a narrow, tested controller, with the media video contained by the available stage and fullscreen viewport.

**Tech Stack:** Vue 3, TypeScript, LiveKit Client 2.22.3, Vitest, CSS custom properties.

---

### Task 1: Specify visible voice status and viewer layout

**Files:**
- Create: `frontend/src/voice/voice_room_presentation.spec.ts`
- Create: `frontend/src/voice/screen_fullscreen_controls.spec.ts`

- [x] **Step 1: Add source contracts for participant and fullscreen affordances.**

Assert that the shared participant status component includes visible muted and speaking labels/icons, the screen viewer exposes a labelled fullscreen toggle and status feedback, the voice room keeps a live roster beside the stream, and CSS makes the video fill its stage with `object-fit: contain`.

- [x] **Step 2: Add fullscreen controller tests.**

Use injected fake `requestFullscreen`, `exitFullscreen`, and `fullscreenchange` ports to assert enter, exit, unavailable, and listener cleanup behavior without requiring a real browser.

- [x] **Step 3: Run both focused tests before implementation.**

Run from `frontend`: `npm test -- voice_room_presentation.spec.ts screen_fullscreen_controls.spec.ts`.
Expected: FAIL because the status, roster, and fullscreen controls have not been implemented.

### Task 2: Make live participant states explicit and persist the roster during screen viewing

**Files:**
- Create: `frontend/src/voice/VoiceParticipantStatus.vue`
- Create: `frontend/src/voice/VoiceParticipantStrip.vue`
- Modify: `frontend/src/voice/VoiceParticipantVolumes.vue`
- Modify: `frontend/src/workspace/WorkspaceApp.vue`
- Modify: `frontend/src/workspace/WorkspaceMembersPanel.vue`
- Modify: `frontend/src/conversation/ConversationPane.vue`
- Modify: `frontend/src/design/voice.css`
- Modify: `frontend/src/design/shell.css`

- [x] **Step 1: Render non-color-only participant state.**

Create one status component that displays an explicit crossed-microphone icon and “Микрофон выключен” when muted, a microphone icon and “В канале” when active but not speaking, and a voice-level icon plus “Говорит” when LiveKit reports speaking. Reuse it in both the room cards and side roster.

- [x] **Step 2: Keep a compact voice roster alongside active screen playback.**

Render a horizontal, keyboard-readable participant strip from the same current-room participant array whenever `ScreenViewer` is shown. Do not synthesize participants or change remote subscription behavior.

- [x] **Step 3: Preserve roster access at desktop compact widths.**

At 1024–1279 CSS px, allocate a 208px member column and keep the central stage flexible; retain the established 1280px and 1440px column tokens. Keep the below-1024 single-column behavior and rely on the in-room strip while screen viewing.

### Task 3: Fit the stage and add browser fullscreen control

**Files:**
- Create: `frontend/src/voice/screen_fullscreen_controls.ts`
- Modify: `frontend/src/voice/ScreenViewer.vue`
- Modify: `frontend/src/design/voice.css`
- Modify: `frontend/src/voice/screen_fullscreen_controls.spec.ts`

- [x] **Step 1: Implement an injected fullscreen controller.**

Expose `toggle`, `sync`, and `dispose`; enter fullscreen on the stage element, exit only when that stage owns fullscreen, synchronize state on `fullscreenchange`, and report unsupported/rejected entry to the component without disrupting voice playback.

- [x] **Step 2: Wire an explicit accessible viewer control.**

Add a labelled expand/restore icon button inside the stage overlay and a polite status line for unsupported or rejected requests. Keep the selected stream and playback lifecycle unchanged.

- [x] **Step 3: Make the stage consume available space.**

Give the stage a shrink-safe flex basis and the video 100% width/height with `object-fit: contain`. In `:fullscreen`, fill `100vw × 100dvh`, remove rounding, and keep the video uncropped.

### Task 4: Validate and record the bounded UI result

**Files:**
- Modify: `docs/superpowers/plans/2026-09-24-voice-room-visibility-and-screen-fullscreen.md`

- [x] **Step 1: Run focused and complete frontend checks.**

Run `npm test -- voice_room_presentation.spec.ts screen_fullscreen_controls.spec.ts`, `npm test`, and `npm run build` from `frontend`.

- [x] **Step 2: Check project contracts and source ratchets.**

Run `scripts/verify-contracts.ps1`, `scripts/verify-spec-traceability.ps1`, and `git diff --check`; count each changed source/test file and keep it at or below 120 lines.

- [ ] **Step 3: Review the live UI without performing owner POC actions.**

Open the frontend preview, verify the channel list, voice roster states, stream sizing, and fullscreen control at a desktop width and a compact width. Do not join or publish real media, and do not claim the physical POC passed.

## Self-review

- **Coverage:** Handles the reported invisible roster during stream viewing, visual speaking/mute indicators, compact desktop roster access, and stage fullscreen sizing.
- **Preservation:** Uses existing LiveKit participant state and selected-stream subscription; no API, ACL, voice lease, or media publication changes.
- **Unverified:** Real screen playback/fullscreen permissions and the requested separate Windows/macOS physical POC runs remain owner checks.
