# Wide Voice Roster Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Match the Voice Room reference by keeping the confirmed room-member panel in the right desktop column at widths of 1280 CSS px and above, while preserving drawer behavior below 1280px.

**Architecture:** `WorkspaceApp.vue` owns whether the real, ACL-backed member panel is mounted. `shell.css` and `responsive_shell.css` own desktop columns and compact drawer placement. The visual-fidelity test guards the breakpoint and prevents a voice-only two-column override from replacing the reference shell.

**Tech Stack:** Vue 3, TypeScript, CSS custom properties, Vitest.

---

### Task 1: Protect the wide-screen Voice Room shell with a failing test

**Files:**
- Modify: `frontend/src/design/design_fidelity.spec.ts`
- Test: `frontend/src/design/design_fidelity.spec.ts`

- [x] **Step 1: Replace the drawer-only voice assertion with the reference behavior.**

```ts
it('keeps the voice members panel in the wide desktop shell and as a drawer below 1280px', () => {
  const shell = source('./shell.css') + source('./responsive_shell.css')
  const app = source('../workspace/WorkspaceApp.vue')
  expect(app).toContain('<WorkspaceMembersPanel v-if="!selectedDirectMessage && activePanel === \'none\'"')
  expect(shell).toContain('grid-template-columns: var(--gc-layout-nav-wide) minmax(0, 1fr) var(--gc-layout-aside-wide)')
  expect(shell).toContain('grid-template-columns: var(--gc-layout-nav-medium) minmax(0, 1fr) var(--gc-layout-aside-medium)')
  expect(shell).toContain('@media (min-width: 1024px) and (max-width: 1279px)')
  expect(shell).toContain('.members.is-open, .search-aside.is-open { display: block; }')
  expect(shell).not.toContain('.gc-shell.voice-room-active { grid-template-columns: var(--gc-layout-nav-wide) minmax(0, 1fr); }')
  expect(shell).not.toContain('.gc-shell.voice-room-active { grid-template-columns: var(--gc-layout-nav-medium) minmax(0, 1fr); }')
})
```

- [x] **Step 2: Run the focused test and confirm it fails against the current drawer-only wide layout.**

Run: `npm test -- src/design/design_fidelity.spec.ts`

Expected: the new fidelity test fails because `WorkspaceApp.vue` excludes the voice panel unless `membersOpen` is true and `responsive_shell.css` collapses voice rooms to two columns at desktop breakpoints.

### Task 2: Restore the reference desktop roster without changing compact layouts

**Files:**
- Modify: `frontend/src/workspace/WorkspaceApp.vue`
- Modify: `frontend/src/design/responsive_shell.css`

- [x] **Step 1: Mount the real member panel whenever a guild workspace screen is active.**

Change only these two exact Vue lines; retain all other children and bindings:

```diff
- <div class="gc-shell" :class="{ 'no-aside': activePanel !== 'search' && (selectedDirectMessage || activePanel !== 'none'), 'voice-room-active': !selectedDirectMessage && activePanel === 'none' && selectedChannel?.kind === 'VOICE', 'voice-members-open': membersOpen }" data-testid="app-shell">
+ <div class="gc-shell" :class="{ 'no-aside': activePanel !== 'search' && (selectedDirectMessage || activePanel !== 'none') }" data-testid="app-shell">
- <WorkspaceMembersPanel v-if="!selectedDirectMessage && activePanel === 'none' && (selectedChannel?.kind !== 'VOICE' || membersOpen)" :open="membersOpen" :active-voice-channel="activeVoiceChannel" :selected-voice-channel="selectedChannel?.kind === 'VOICE' ? selectedChannel : null" :participants="voiceConnection.voiceVolumeParticipants" :presence-resolver="guildPresence.resolve" :role="props.role" :account-i-d="profile?.account_id" :self-name="profile?.display_name ?? null" :self-microphone-muted="voiceConnection.microphoneMuted" :self-microphone-unavailable="voiceConnection.microphonePermissionDenied" @open-d-m="openDirectMessageFromMember" @set-volume="setParticipantVolume" />
+ <WorkspaceMembersPanel v-if="!selectedDirectMessage && activePanel === 'none'" :open="membersOpen" :active-voice-channel="activeVoiceChannel" :selected-voice-channel="selectedChannel?.kind === 'VOICE' ? selectedChannel : null" :participants="voiceConnection.voiceVolumeParticipants" :presence-resolver="guildPresence.resolve" :role="props.role" :account-i-d="profile?.account_id" :self-name="profile?.display_name ?? null" :self-microphone-muted="voiceConnection.microphoneMuted" :self-microphone-unavailable="voiceConnection.microphonePermissionDenied" @open-d-m="openDirectMessageFromMember" @set-volume="setParticipantVolume" />
```

Keep `:open="membersOpen"`; below 1280px the CSS continues to show the aside only after the user opens the drawer.

- [x] **Step 2: Remove the desktop-only voice-room collapse and overlay rules.**

Delete the wide voice-only overrides. Keep this compact rule intact so the roster remains a drawer from 1024 through 1279px:

```css
@media (min-width: 1024px) and (max-width: 1279px) {
  .app-frame { padding: var(--gc-layout-frame-medium); }
  .gc-shell { min-height: 0; height: calc(100dvh - 32px); grid-template-columns: var(--gc-layout-nav-small) minmax(0, 1fr); border: 1px solid var(--gc-border-subtle); border-radius: var(--gc-radius-lg); }
  .gc-shell.no-aside { grid-template-columns: var(--gc-layout-nav-small) minmax(0, 1fr); }
  .members, .search-aside { position: absolute; inset: 0 0 0 auto; z-index: 31; width: min(320px, calc(100% - 32px)); border-left: 1px solid var(--gc-border-subtle); box-shadow: var(--gc-shadow-shell); }
  .members.is-open, .search-aside.is-open { display: block; }
}
```

### Task 3: Verify the reference behavior and responsive regression boundary

**Files:**
- Test: `frontend/src/design/design_fidelity.spec.ts`
- Check: `frontend/package.json`

- [x] **Step 1: Run the focused test.**

Run: `npm test -- src/design/design_fidelity.spec.ts`

Expected: all fidelity assertions pass; desktop Voice Room retains wide/medium three-column geometry, and compact layouts retain the existing member drawer.

- [x] **Step 2: Run the full frontend suite and production build.**

Run: `npm test`; then `npm run build`.

Expected: the complete frontend suite passes and `vue-tsc` plus Vite build pass. This source/test/build evidence does not replace connected-state screenshots or production visual acceptance.

## Self-review

- **Spec coverage:** Covers S-06 `MembersPanel`, C-26 wide/medium geometry, the three-region desktop shell, and the documented compact drawer breakpoint.
- **Preservation:** Keeps the real server-derived member/voice data, existing ACL behavior, open-drawer state, all narrow layouts, and unrelated realtime changes in `WorkspaceApp.vue`.
- **Limit:** Does not resolve the separate HTML-preview vs C-28/C-29 participant-card-height discrepancy and does not claim pixel-level acceptance without connected production captures.
