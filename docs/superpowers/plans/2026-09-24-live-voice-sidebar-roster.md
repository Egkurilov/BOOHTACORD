# Live Voice Sidebar Roster Implementation Plan

> **For agentic workers:** Follow the repository Slavik Gym workflow and execute this single bounded T-050 leaf inline with test-first checkpoints.

**Goal:** Show only real participants of the currently connected voice room beneath its channel row, with visible speaking, microphone, and screen-sharing status.

**Architecture:** Build a small navigation view model from the existing LiveKit participant cards, local participant state, and active room screen publications. Keep the channel component presentational; it receives one room-scoped view model and renders it only under the matching active voice channel. Never infer occupancy for rooms the client has not joined.

**Tech Stack:** Vue 3, TypeScript, CSS custom properties, Vitest.

---

### Task 1: Add focused tests for truthful voice navigation presence

**Files:**
- Create: `frontend/src/channel/voice_navigation_presence.spec.ts`
- Test: `frontend/src/channel/voice_navigation_presence.ts`
- Inspect: `frontend/src/channel/ChannelNavigation.vue`, `frontend/src/workspace/WorkspaceApp.vue`

- [ ] Test that no active channel produces no roster.
- [ ] Test that an active room produces one local row plus exactly the supplied LiveKit remote participants, a count equal to those rows, and the correct mute/speaking/share fields.
- [ ] Test that the navigation binds the active room view model and renders rows only under its matching channel.
- [ ] Run `npm test -- src/channel/voice_navigation_presence.spec.ts` from `frontend`; confirm the missing helper causes the expected failure.

### Task 2: Bind and render the active room roster

**Files:**
- Create: `frontend/src/channel/voice_navigation_presence.ts`
- Modify: `frontend/src/channel/ChannelNavigation.vue`
- Modify: `frontend/src/design/navigation.css`
- Modify: `frontend/src/workspace/WorkspaceApp.vue`

- [ ] Map `voiceConnection.voiceVolumeParticipants`, local microphone/speaking state, and `screenViewerCards` into rows only when `activeVoiceChannel` exists.
- [ ] Render the count and nested rows only when the view model channel ID equals the row channel ID; keep selected-channel and connected-channel state independent.
- [ ] Reuse `VoiceParticipantStatus` for microphone/speaking icons and accessible labels; identify active screen publishers without inventing remote data.
- [ ] Keep the nested list inside the existing independently scrolling navigation region and use the design contract's 36px row height and 40px indent.

### Task 3: Validate the leaf

- [ ] Run the focused Vitest file.
- [ ] Run the complete frontend suite and `npm run build`.
- [ ] Inspect changed file sizes, ensure no production file exceeds the 120-line hard ratchet, and verify `git diff --check` for only this packet.
- [ ] Do not stage, commit, deploy, or alter unrelated dirty worktree changes in this packet.

## Review notes

- The supplied ChannelNavigation contract C-15 explicitly includes `VoiceMemberRow` and requires the list to scroll while the dock remains fixed.
- The preview's synthetic counts for other rooms are not production data. This implementation intentionally shows presence only for the room represented by the current LiveKit connection.
- The PNG's additional main-area leave bar conflicts with C-18, which says voice controls belong only in the VoiceDock; this packet does not duplicate those controls.
