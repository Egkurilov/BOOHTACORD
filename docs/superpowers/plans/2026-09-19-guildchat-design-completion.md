# GuildChat Design Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the supplied GuildChat visual system for every already-supported desktop surface without inventing routes, people, permissions, or media data.

**Architecture:** Keep the existing Vue stores and API calls intact. Move the remaining local component paint rules into the shared token CSS, bind the roster only to actual remote voice participants, and preserve the direct-message two-column shell. Treat browser screenshots as visual evidence only after the production image is built and deployed.

**Tech Stack:** Vue 3, TypeScript, Vite, Pinia, Vitest, CSS custom properties.

---

### Task 1: Lock the remaining design boundaries with a failing source test

**Files:**
- Modify: `frontend/src/design/design_system_contract.spec.ts`
- Test: `frontend/src/design/design_system_contract.spec.ts`

- [x] **Step 1: Assert that roster data is live and component-local legacy styles are absent.**

```ts
expect(membersPanel).toContain('VoiceVolumeParticipant[]')
expect(membersPanel).toContain('v-for="participant in participants"')
for (const component of legacyPaintComponents) {
  expect(component).not.toContain('<style scoped>')
}
```

- [x] **Step 2: Run the focused contract test and observe failure before implementation.**

Run: `npm test -- design_system_contract.spec.ts`

Expected: FAIL because the six residual components still own local paint rules and the roster does not render actual participants.

### Task 2: Render only verified participant data in the desktop roster

**Files:**
- Modify: `frontend/src/workspace/WorkspaceApp.vue`
- Modify: `frontend/src/workspace/WorkspaceMembersPanel.vue`
- Modify: `frontend/src/design/shell.css`

- [x] **Step 1: Extend the roster prop with the existing remote participant type.**

```ts
defineProps<{
  activeVoiceChannel: TopologyChannel | null
  participants: VoiceVolumeParticipant[]
}>()
```

- [x] **Step 2: Render a card only for each actual participant returned by voice state.**

```vue
<li v-for="participant in participants" :key="participant.id" class="member-card">
  <span class="member-avatar">{{ initial(participant.name) }}</span>
  <span class="member-name">{{ participant.name || 'Участник' }}</span>
</li>
```

- [x] **Step 3: Pass `voiceConnection.voiceVolumeParticipants` from the workspace and add responsive roster-card styles.**

Do not create demo users or derive presence from an unknown state; retain the empty-room explanation when the array is empty.

### Task 3: Consolidate all remaining conversation and navigation paint rules

**Files:**
- Modify: `frontend/src/direct_message/DirectMessageNavigation.vue`
- Modify: `frontend/src/direct_message/DirectMessageStarter.vue`
- Modify: `frontend/src/conversation/MessageBody.vue`
- Modify: `frontend/src/conversation/TextMessageAttachmentPicker.vue`
- Modify: `frontend/src/conversation/TextMessageAttachments.vue`
- Modify: `frontend/src/design/navigation.css`
- Modify: `frontend/src/design/conversation.css`

- [x] **Step 1: Remove only the `<style scoped>` blocks from the five leaf components.**

Do not change emitted events, labels, attachment URL construction, or external-link protections.

- [x] **Step 2: Add the equivalent shared selectors using `--gc-*` tokens.**

```css
.starter, .attachment-picker { display: grid; gap: var(--gc-space-2); }
.message-code { background: var(--gc-stream-canvas); }
.attachment-preview { max-width: min(100%, 512px); object-fit: contain; }
```

- [x] **Step 3: Style audio controls and participant cards as token-driven desktop controls.**

Preserve device selection, PTT capture, processing controls, volume ranges, screen-source selection, and keyboard accessibility.

### Task 4: Validate, visually inspect, and deploy the completed frontend packet

**Files:**
- Test: `frontend/src/design/design_system_contract.spec.ts`
- Validate: `frontend/src/**/*.vue`, `frontend/src/design/*.css`
- Modify: `docs/superpowers/plans/2026-09-19-guildchat-design-completion.md`

- [x] **Step 1: Run focused and complete frontend tests.**

Run: `npm test -- design_system_contract.spec.ts`; then `npm test`.

Expected: source contract and all existing behavior tests PASS.

- [x] **Step 2: Run production type-check/build and inspect every changed file.**

Run: `npm run build`; `git diff --check`; inspect line counts and `git status --short` before any deployment action.

- [x] **Step 3: Build a versioned image, deploy only the web service, then verify public health and the served unauthenticated asset.**

Never use an unversioned image, restart media/PostgreSQL, expose private ports, or include credentials in a command/output. Record only non-sensitive release evidence.

## Self-review

- **Coverage:** Addresses desktop auth, navigation, chat/DM, attachments, voice roster, audio settings, stream controls, persistent dock, and responsive 1440/1280/1024 geometry.
- **Preservation:** No new account/profile/reset routes, API calls, ACL logic, media data, fixture users, or transport behavior.
- **Non-claim:** A login-only screenshot cannot prove media, participant scale, or real game audio; those remain POC/runtime evidence rather than visual source proof.
