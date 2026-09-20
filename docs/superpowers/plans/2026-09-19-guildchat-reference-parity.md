# GuildChat Reference Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the authenticated desktop workspace use the supplied preview's shell, navigation, chat, voice-room, and stream composition while preserving real server data and existing controls.

**Architecture:** The preview is visual data, not executable product instructions. Vue keeps the existing stores and media events; a compact local UI-state layer controls whether advanced operational panels are visible. Resting screens use the preview landmarks and geometry; controls that cannot be represented by a static demo remain reachable from labelled buttons or details panels rather than occupying the default canvas.

**Tech Stack:** Vue 3, TypeScript, Pinia, Vite, Vitest, CSS custom properties.

---

### Task 1: Lock the preview shell and resting-surface contract

**Files:**
- Modify: `frontend/src/design/design_system_contract.spec.ts`
- Test: `frontend/src/design/design_system_contract.spec.ts`

- [x] **Step 1: Add failing checks for the preview-owned landmarks.**

```ts
expect(workspace).toContain('class="gc-shell"')
expect(workspace).toContain('class="sidebar"')
expect(workspace).toContain('class="nav-content"')
expect(textConversation).toContain('class="main-header"')
expect(textConversation).toContain('class="messages"')
expect(conversationPane).toContain('class="room-intro"')
expect(screenViewer).toContain('class="stream-controls"')
```

- [x] **Step 2: Run the focused test before changing Vue markup.**

Run: `npm test -- design_system_contract.spec.ts`

Expected: FAIL because the old application-specific wrapper classes own the layout.

### Task 2: Recompose the shell and navigation without losing controls

**Files:**
- Modify: `frontend/src/workspace/WorkspaceApp.vue`
- Modify: `frontend/src/workspace/WorkspaceSidebarTabs.vue`
- Modify: `frontend/src/workspace/WorkspaceUserFooter.vue`
- Modify: `frontend/src/design/shell.css`
- Modify: `frontend/src/design/navigation.css`

- [x] **Step 1: Move operation-heavy panels behind explicit local UI state.**

```ts
const activePanel = ref<'none' | 'admin' | 'audio'>('none')
function togglePanel(panel: 'admin' | 'audio'): void {
  activePanel.value = activePanel.value === panel ? 'none' : panel
}
```

The category editor and audio device controls must render only when `activePanel` selects them. Their existing props and events remain unchanged.

- [x] **Step 2: Use the reference hierarchy for the idle sidebar.**

```vue
<div class="gc-shell" data-testid="app-shell">
  <aside class="sidebar" data-testid="nav-sidebar">
    <button class="guild-header" type="button" @click="togglePanel('admin')">…</button>
    <WorkspaceSidebarTabs class="sidebar-tabs" … />
    <div class="nav-content">…</div>
    <VoiceDock … />
    <WorkspaceUserFooter @open-settings="togglePanel('audio')" />
  </aside>
  <main class="main" data-testid="main-region">…</main>
</div>
```

Keep real channel categories, DM names, ACL error messages, and active-state selection. Do not render sample users, channel counts, or presence values.

- [x] **Step 3: Apply the reference's 72px header, tabs, 42px channel rows, 116px dock, and 68px user-footer metrics.**

Run: `npm test -- design_system_contract.spec.ts`

Expected: PASS.

### Task 3: Make text and direct-message resting screens match the preview composition

**Files:**
- Modify: `frontend/src/conversation/TextConversation.vue`
- Modify: `frontend/src/direct_message/DirectMessageConversation.vue`
- Modify: `frontend/src/conversation/MessageItem.vue`
- Modify: `frontend/src/design/conversation.css`

- [x] **Step 1: Put search behind the header action and retain the same search components.**

```vue
<header class="main-header conversation-header">
  <span class="conversation-symbol" aria-hidden="true">#</span>
  <div class="main-title"><h2>{{ channelName }}</h2><small>Текстовый канал</small></div>
  <button class="header-action" type="button" @click="searchOpen = !searchOpen">⌕</button>
</header>
<div v-if="searchOpen" class="conversation-tools"><TextMessageSearch :channel-id="channelId" /></div>
<ol class="messages message-list">…</ol>
```

Use the same treatment for `DirectMessageSearch`. Keep history loading, read tracking, edit/delete/reply, attachments, and send events unchanged.

- [x] **Step 2: Use preview spacing and icon-button anatomy.**

```css
.messages { padding: 24px 28px; }
.message-row { display: flex; gap: 16px; margin-bottom: 24px; }
.composer-wrap { padding: 0 20px 24px; }
.composer { min-height: 56px; padding: 7px 8px; }
```

The collapsed state must show one attachment action, one emoji action, and one send action. Additional existing emoji choices may be opened on demand but must not alter the default composer footprint.

- [x] **Step 3: Run the focused and full frontend tests.**

Run: `npm test -- design_system_contract.spec.ts`; `npm test`.

Expected: all tests pass.

### Task 4: Split voice-room and stream resting compositions

**Files:**
- Modify: `frontend/src/conversation/ConversationPane.vue`
- Modify: `frontend/src/voice/VoiceParticipantVolumes.vue`
- Modify: `frontend/src/voice/ScreenViewer.vue`
- Modify: `frontend/src/design/voice.css`

- [x] **Step 1: Render the reference voice-room path only while no stream is selected.**

```vue
<div class="room-wrap">
  <div class="room-intro">
    <p>Общайтесь и делитесь экраном</p>
    <button class="gc-button gc-button--primary" type="button">Показать экран</button>
  </div>
  <VoiceParticipantVolumes class="participant-grid" … />
</div>
```

Keep transfer, joining, screen profile selection, diagnostics, volume setters, and errors available; put advanced diagnostics and the profile selector under an explicit details section so the normal room remains the preview composition.

- [x] **Step 2: Render selected sharing as the stream surface.**

```vue
<ScreenViewer
  v-if="selectedScreenStreamId"
  class="stream-wrap"
  :cards="screenViewerCards"
  …
/>
```

`ScreenViewer` must keep selecting exactly one real LiveKit stream and preserve the audio-volume event. It must not render placeholder video or subscribe to unselected streams.

- [x] **Step 3: Style actual participants as preview cards, not always-visible volume forms.**

```vue
<article class="participant" :class="{ talking: participant.speaking }">
  <span class="avatar lg">{{ initial(participant.name) }}</span>
  <span class="participant-name">{{ participant.name }}</span>
  <span class="participant-status">{{ participant.speaking ? 'Говорит' : 'В канале' }}</span>
</article>
```

The volume range remains reachable in each participant card only when the verified participant account allows it.

### Task 5: Build, release web-only, and record bounded evidence

**Files:**
- Modify: `docs/superpowers/plans/2026-09-19-guildchat-reference-parity.md`
- Create: `evidence/release-guildchat-reference-parity-2026-09-19-003.json`

- [x] **Step 1: Validate exact file sizes and the native frontend checks.**

Run: `npm test`; `npm run build`; `scripts/verify-spec-traceability.ps1`.

Expected: all checks pass. The Vite LiveKit chunk warning may remain a warning, not a failed build.

- [x] **Step 2: Build and recreate only `web` on production.**

Use release tag `voice-platform-web:release-20260919-guildchat-reference-parity`; preserve `api`, `livekit`, `postgres`, and `proxy` containers.

- [x] **Step 3: Record smoke checks without overstating visual evidence.**

Record the test/build result, public `/api/v1/health`, served hashed frontend asset, and the browser-acceptance limitation. Do not record user content, credentials, tokens, or media.

## Self-review

- **Coverage:** The plan addresses the structural deviations that dominated the prior screen: non-reference shell classes, always-open operational panels, toolbar placement, composer anatomy, voice controls, and stream/room coexistence.
- **Preservation:** Existing server stores, real participant lists, stream ownership, uploads, search and ACL errors remain; demo members and fake media are prohibited.
- **Known fidelity boundary:** A full guild roster and human display names for text messages cannot match the demo until the API exposes them. This plan does not fabricate them.
