# GuildChat Workspace Panel Layout Implementation Plan

> **For agentic workers:** Execute the checked steps in order. Keep this packet scoped to repositioning the already-supported audio and channel-management surfaces.

**Goal:** Match the design system's settings/admin composition by rendering existing panels in the central workspace, keeping guild navigation and the voice dock persistent, and hiding the members aside on those screens.

**Architecture:** `WorkspaceApp.vue` continues to own application state and existing API/media stores. It supplies the current audio/admin controls through named slots on `WorkspaceMain.vue`; `WorkspaceMain.vue` chooses between those surfaces and `ConversationPane.vue`. A focused design contract protects the composition, while a new small CSS module sets the documented 720px audio and 1120px admin content widths.

**Tech Stack:** Vue 3, TypeScript, CSS custom properties, Vitest.

---

### Task 1: Protect the intended central panel composition

**Files:**
- Modify: `frontend/src/design/design_system_contract.spec.ts`
- Read: `frontend/src/workspace/WorkspaceApp.vue`
- Read: `frontend/src/workspace/WorkspaceMain.vue`
- Read: `frontend/src/design/shell.css`

- [x] **Step 1: Require persistent navigation and central named panel slots.**

Add one contract test requiring the sidebar navigation to remain in `WorkspaceApp.vue`, audio/admin content to be passed through named slots, `WorkspaceMain.vue` to render those panels centrally, and the shell to hide its members aside while a panel is active.

- [x] **Step 2: Run the focused test and confirm the old composition fails.**

Run from `frontend`: `npm test -- design_system_contract.spec.ts`.

Expected: FAIL because `AudioSettings` and `AdminTopologyControls` currently replace `.nav-content` and the shell only hides the aside for direct messages.

### Task 2: Render existing workspace panels in the center

**Files:**
- Modify: `frontend/src/workspace/WorkspaceApp.vue`
- Modify: `frontend/src/workspace/WorkspaceMain.vue`
- Create: `frontend/src/design/settings.css`
- Modify: `frontend/src/style.css`
- Test: `frontend/src/design/design_system_contract.spec.ts`

- [x] **Step 1: Move the two existing control components into `WorkspaceMain` slots.**

Keep `ChannelNavigation` and `DirectMessageNavigation` inside `.nav-content`. Pass the existing `AdminTopologyControls` through `#admin` and `AudioSettings` through `#audio`; do not change their props, API calls, media events, or store ownership. Selecting a channel or DM returns the workspace to the conversation surface.

- [x] **Step 2: Make the shell hide members for DM, audio, and admin surfaces.**

Derive the existing `no-aside` class from `selectedDirectMessage || activePanel !== 'none'`. Keep the persistent VoiceDock in the sidebar.

- [x] **Step 3: Style the main panel to the screen contracts.**

Use a scrollable central panel with 24px desktop padding, a maximum width of 720px for audio settings and 1120px for channel administration, token-based colors and spacing, and no fixed overlay that covers the composer or sidebar.

- [x] **Step 4: Run the focused contract and frontend production build.**

Run from `frontend`: `npm test -- design_system_contract.spec.ts`; then `npm run build`.

Expected: the contract passes, Vue type-check succeeds, and Vite emits the production bundle.

### Task 3: Update the design TODO and implementation status

**Files:**
- Modify: `docs/design/GUILDCHAT_V1_STATUS.md`
- Modify: `docs/superpowers/plans/2026-09-23-guildchat-workspace-panels.md`

- [x] **Step 1: Record this panel-placement packet and list the remaining screen gaps.**

Keep visual screenshot acceptance `NOT_RUN` until an actual browser comparison is available. Record profile settings, complete member/audit administration, responsive drawer review, keyboard review, and visual evidence as separate open items unless existing source and tests prove them complete.

- [x] **Step 2: Review the changed paths and file sizes.**

Run `git status --short`, `git diff --check`, and inspect line counts for every changed production and test file before staging.

## Self-review

- **Coverage:** Addresses the current placement mismatch for supported audio and channel-management panels; it does not claim the complete ProfileSettings or AdminPanel contracts already exist.
- **Preservation:** Retains the existing channel/topology clients, audio settings events, voice state, and media controls.
- **Visual evidence:** Unit/source contracts and a production build do not count as screenshot parity evidence.
