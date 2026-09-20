# GuildChat Design Foundation Implementation Plan

> **Tracking:** Checkbox states document the completed bounded implementation packet.

**Goal:** Apply the GuildChat dark design tokens, responsive shell, conversation treatment, and voice-room cards to the existing Vue client without changing API, ACL, or media ownership.

**Architecture:** Split source-owned CSS into tokens, foundation, authentication, shell, navigation, voice, and conversation modules. Rework existing Vue containers to use those contracts while retaining all current stores and API calls. A focused Vitest source contract protects exact tokens, breakpoints, semantic landmarks, a persistent VoiceDock, and absence of conflicting legacy component styles.

**Tech Stack:** Vue 3, TypeScript, Vite, Vitest, CSS custom properties.

---

### Task 1: Establish a failing visual-contract test

**Files:**
- Create: `frontend/src/design/design_system_contract.spec.ts`
- Test: `frontend/src/design/design_system_contract.spec.ts`

- [x] **Step 1: Require the dark-only token values and responsive shell selectors.**

Test for `--gc-canvas: #0E1117`, `--gc-accent: #5C5FE8`, `--gc-layout-nav-wide: 312px`, `--gc-layout-aside-wide: 312px`, a 1440px shell rule, a 1280px shell rule, a 1024px compact rule, and `prefers-reduced-motion`.

- [x] **Step 2: Require accessible shell and voice markup.**

Read the existing `WorkspaceApp.vue` and `VoiceDock.vue` source through `node:fs`; require `data-testid="app-shell"`, `main-region`, `members-panel`, and `data-testid="voice-dock"` without asserting user content.

- [x] **Step 3: Run the focused test.**

Run: `npm test -- design_system_contract.spec.ts`.

Expected: failure because the design module and required data attributes do not yet exist.

### Task 2: Add CSS design foundations

**Files:**
- Create: `frontend/src/design/tokens.css`
- Create: `frontend/src/design/foundation.css`
- Create: `frontend/src/design/authentication.css`
- Create: `frontend/src/design/shell.css`
- Create: `frontend/src/design/navigation.css`
- Create: `frontend/src/design/voice.css`
- Create: `frontend/src/design/conversation.css`
- Create: `frontend/src/design/test_node_fs.d.ts`
- Modify: `frontend/src/style.css`

- [x] **Step 1: Define the supplied dark tokens in `--gc-*`.**

Use only the product dark palette, Inter/system fallback, 4px spacing scale, 32/40/48px controls, 312/264/256px navigation widths, 312/240px member widths, and 120/180/240ms timing. Do not include a theme switcher or the archive's light reference palette.

- [x] **Step 2: Add common accessibility and primitive styling.**

Define `box-sizing`, visible `:focus-visible`, reduced-motion handling, screen-reader-only utility, buttons, inputs, status banner, icon-button hit area, and 40px form controls through tokens.

- [x] **Step 3: Implement responsive shell and state styling.**

At wide size use a framed three-column grid. At medium size use 264px/240px side columns. At 1024px hide the members column and reduce navigation to 256px; below 1024px collapse to one content column without adding a mobile product mode. Make each scroll area `min-height: 0` and preserve the VoiceDock over the UserFooter area.

- [x] **Step 4: Replace legacy global rules with module imports.**

Keep `style.css` as imports only, so no CSS file exceeds the project line ratchet.

### Task 3: Bind existing containers to the design system

**Files:**
- Modify: `frontend/src/workspace/WorkspaceApp.vue`
- Create: `frontend/src/workspace/WorkspaceMain.vue`
- Create: `frontend/src/workspace/WorkspaceMembersPanel.vue`
- Create: `frontend/src/workspace/WorkspaceUserFooter.vue`
- Modify: `frontend/src/channel/ChannelNavigation.vue`
- Modify: `frontend/src/voice/VoiceDock.vue`
- Modify: `frontend/src/identity/AuthenticationLanding.vue`
- Modify: `frontend/src/maintenance/MaintenanceBanner.vue`
- Modify: `frontend/src/conversation/TextConversation.vue`
- Modify: `frontend/src/direct_message/DirectMessageConversation.vue`
- Modify: `frontend/src/conversation/MessageItem.vue`

- [x] **Step 1: Give workspace three truthful regions.**

Add a guild header with the existing product name, `nav`, `main`, and a member state panel. Keep actual topology, direct-message, realtime, and voice stores unchanged. The members panel must say that participant information is shown by a voice room instead of inventing people.

- [x] **Step 2: Distinguish selected and connected voice channels.**

Pass `activeVoiceChannel?.id` into navigation. Render a text channel `#` and an inline SVG voice icon, with a green connected marker only for the actual active voice channel; preserve admission-closed status.

- [x] **Step 3: Make VoiceDock persistent and operable.**

Add labelled SVG icon buttons for mic, deafen, share, and leave. Emit a new explicit `start-screen` event only while connected and bind it to the existing user-triggered `startScreen` control. Preserve PTT/deafen disable rules and existing leave semantics.

- [x] **Step 4: Rebuild the authentication and maintenance presentation.**

Keep login/register calls, validation attributes, and error messages intact; add labels, 40px fields, tabs, and a non-overlapping maintenance banner with the supplied dark tokens.

### Task 4: Validate the first design slice

**Files:**
- Test: `frontend/src/design/design_system_contract.spec.ts`
- Validate: `frontend/src/**/*.vue`
- Modify: `docs/superpowers/plans/2026-09-19-guildchat-design-foundation.md`

- [x] **Step 1: Run the focused UI contract test.**

Run: `npm test -- design_system_contract.spec.ts`.

Expected: PASS.

- [x] **Step 2: Run the complete frontend suite and build.**

Run: `npm test` and `npm run build`.

Expected: all existing behavior tests pass and Vite emits a production build.

- [x] **Step 3: Inspect bounded files and mark complete.**

Run `git diff --check` for the twelve packet files, inspect their sizes, then change these checkboxes to `[x]`. Do not stage shared-worktree files.

## Self-review

- **Coverage:** Uses the supplied dark tokens, 1440/1280/1024 geometry, controls, landmarks, VoiceDock, and authentication contracts.
- **Preservation:** Existing API calls, Pinia stores, role handling, screen publication, and media connection ownership remain unchanged.
- **Non-claim:** No screenshot comparison, browser E2E, or real-media acceptance is implied by source styling and a production build.
