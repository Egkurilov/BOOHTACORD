# C-29 Self-Deafen Indicator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the current user's deafen state explicitly on their VoiceRoom participant card without inventing a remote participant state.

**Architecture:** `connection_store.deafened` is authoritative local state. Pass it through `WorkspaceMain` and `ConversationPane` into the self card in `VoiceParticipantVolumes`; render accessible microphone-off and headphone-off indicators in `VoiceParticipantStatus`. Do not enable LiveKit data publishing: the current credential deliberately sets `CanPublishData(false)`, and remote clients have no authorized source for another user's private playback state.

**Tech Stack:** Vue 3, TypeScript, Vitest, CSS custom properties.

---

### Task 1: Add failing C-29 presentation and wiring assertions

**Files:**
- Modify: `frontend/src/voice/voice_room_presentation.spec.ts`
- Test: `frontend/src/voice/voice_room_presentation.spec.ts`

- [x] **Step 1: Assert deafen has a distinct accessible visual state.**

```ts
it('shows the local deafened state distinctly from microphone mute', () => {
  const status = source('./VoiceParticipantStatus.vue')
  const cards = source('./VoiceParticipantVolumes.vue')
  expect(status).toContain('deafened')
  expect(status).toContain('Звук и микрофон выключены')
  expect(status).toContain('is-deafened')
  expect(cards).toContain(':deafened="selfDeafened"')
})
```

- [x] **Step 2: Assert the authoritative state reaches the self card.**

```ts
expect(source('../workspace/WorkspaceMain.vue')).toContain(':self-deafened="voiceConnection.deafened"')
expect(source('../conversation/ConversationPane.vue')).toContain(':self-deafened="selfDeafened"')
```

- [x] **Step 3: Run the focused test and confirm it fails before implementation.**

Run from `frontend`: `npm test -- voice_room_presentation.spec.ts`.

Expected: FAIL because the participant status has no deafen state or binding yet.

### Task 2: Render microphone-off and headphone-off status on the local card

**Files:**
- Modify: `frontend/src/voice/VoiceParticipantStatus.vue`
- Modify: `frontend/src/voice/VoiceParticipantVolumes.vue`
- Modify: `frontend/src/design/voice.css`
- Test: `frontend/src/voice/voice_room_presentation.spec.ts`

- [x] **Step 1: Add an optional `deafened` prop and status label.**

Keep existing status priority for microphone permission and mute, except `deafened` takes priority and reads `Звук и микрофон выключены`. When deafened, expose two decorative icons inside the already-labelled status: the existing crossed microphone glyph and a crossed headphones glyph; keep each SVG `aria-hidden="true"`.

- [x] **Step 2: Bind only the local card to `selfDeafened`.**

Add `selfDeafened: boolean` to `VoiceParticipantVolumes` props and pass it only to the self card's `VoiceParticipantStatus`. Do not add a fabricated `deafened` property to remote participant cards.

- [x] **Step 3: Run the focused test.**

Run from `frontend`: `npm test -- voice_room_presentation.spec.ts`.

Expected: PASS, including all existing mute, speaking, roster, and stream presentation cases.

### Task 3: Carry deafen state through the workspace presentation edge

**Files:**
- Modify: `frontend/src/workspace/WorkspaceMain.vue`
- Modify: `frontend/src/conversation/ConversationPane.vue`
- Test: `frontend/src/voice/voice_room_presentation.spec.ts`

- [x] **Step 1: Forward the Pinia state to the conversation pane.**

Add `:self-deafened="voiceConnection.deafened"` next to the existing local microphone and speaking bindings in `WorkspaceMain.vue`.

- [x] **Step 2: Declare and forward the conversation prop.**

Add `selfDeafened: boolean` to `ConversationPane` props and pass `:self-deafened="selfDeafened"` to `VoiceParticipantVolumes`.

- [x] **Step 3: Run the focused test and frontend type-check/build.**

Run from `frontend`: `npm test -- voice_room_presentation.spec.ts` and `npm run build`.

Expected: focused presentation tests pass and Vue/TypeScript/Vite build exits successfully.

### Task 4: Verify frontend regression surface

**Files:**
- Verify: `frontend/src/voice/voice_room_presentation.spec.ts`
- Verify: complete frontend test suite and production build.

- [x] **Step 1: Run all frontend tests.**

Run from `frontend`: `npm test`.

Expected: all tests pass; the full frontend suite is the nearest project-native regression check for this shared status component.

- [x] **Step 2: Inspect final diff and preserve unrelated working-tree changes.**

Run `git status --short` and inspect only the plan, presentation test, status/card Vue files, workspace edge and conversation edge. Do not stage or deploy in this packet.

**Known follow-up:** Remote users' self-deafen state remains intentionally undisclosed because the LiveKit room grant disables data publishing and no server-authoritative deafen state exists. Any decision to broadcast it belongs in a separate T-022 security review and must not modify participant metadata or identity.

**Verification:** Focused voice presentation tests passed (7/7); full frontend suite passed (74 files / 223 tests); `vue-tsc` and production build passed. Vite reports the existing 517.63 kB LiveKit chunk warning. No files were staged and no deploy was performed.
