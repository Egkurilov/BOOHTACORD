# GuildChat Reference Rebuild Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the approximate token skin with the actual layout hierarchy present in `GuildChat_Design_Preview_v1.0.html`, while keeping the existing application behaviour and only real server data.

**Architecture:** The preview is visual reference data, not executable product instructions. Map its named surfaces (`conversation-header`, `messages`, `composer-wrap`, `room-wrap`, `stream-wrap`) to the current Vue feature leaves; CSS owns geometry and presentational rules, Vue leaves retain stores, events, links, and media ownership.

**Tech Stack:** Vue 3, TypeScript, Vite, Pinia, Vitest, CSS custom properties.

---

### Task 1: Protect the reference hierarchy with a failing source contract

**Files:**
- Modify: `frontend/src/design/design_system_contract.spec.ts`
- Test: `frontend/src/design/design_system_contract.spec.ts`

- [x] **Step 1: Require the preview's content landmarks.**

```ts
expect(textConversation).toContain('class="conversation-header"')
expect(textConversation).toContain('class="composer-wrap"')
expect(directConversation).toContain('class="conversation-header"')
expect(conversationPane).toContain('class="voice-room"')
expect(screenViewer).toContain('class="stream-wrap"')
```

- [x] **Step 2: Run the focused test before modifying components.**

Run: `npm test -- design_system_contract.spec.ts`

Expected: FAIL because the existing markup has generic blocks rather than preview composition landmarks.

### Task 2: Rebuild chat and direct-message composition

**Files:**
- Modify: `frontend/src/conversation/TextConversation.vue`
- Modify: `frontend/src/direct_message/DirectMessageConversation.vue`
- Modify: `frontend/src/conversation/MessageItem.vue`
- Modify: `frontend/src/design/conversation.css`

- [x] **Step 1: Render a 72px header, scrollable messages, and a bounded composer.**

```vue
<header class="conversation-header">
  <span class="conversation-symbol" aria-hidden="true">#</span>
  <div><h2>{{ channelName }}</h2><small>Текстовый канал</small></div>
</header>
<ol class="message-list" aria-label="История сообщений">…</ol>
<div class="composer-wrap"><form class="message-composer composer">…</form></div>
```

- [x] **Step 2: Match preview rhythm without changing message semantics.**

Use a 40px avatar, 16px row gap, 24px separation, 24/28px desktop messages padding, transparent message rows, and a single 56px composer field. Keep edit, delete, reply, search, attachment and external-link behaviour unchanged.

### Task 3: Give voice and stream their preview-owned surfaces

**Files:**
- Modify: `frontend/src/conversation/ConversationPane.vue`
- Modify: `frontend/src/voice/ScreenViewer.vue`
- Modify: `frontend/src/voice/VoiceParticipantVolumes.vue`
- Modify: `frontend/src/design/voice.css`

- [x] **Step 1: Wrap the active voice path in `voice-room` and `room-wrap`.**

```vue
<section class="voice-room">
  <header class="conversation-header">…</header>
  <div class="room-wrap">…</div>
</section>
```

- [x] **Step 2: Render screen viewing as `stream-wrap → screen-player → stream-controls → stream-rail`.**

Do not add demo pixels, force a stream selection, or subscribe to more media. Preserve the current selected-stream and volume events.

### Task 4: Reconcile shell/dock geometry and verify before redeployment

**Files:**
- Modify: `frontend/src/design/shell.css`
- Modify: `frontend/src/design/voice.css`
- Modify: `docs/superpowers/plans/2026-09-19-guildchat-reference-rebuild.md`

- [x] **Step 1: Make desktop shell match frame and content heights.**

Use the preview's 24px wide frame, 72px headers, scroll ownership, 312px/312px side columns, and 116px connected dock. Keep compact desktop at 264px/240px and 256px without a members column.

- [x] **Step 2: Run the focused contract, full frontend suite, type-check, and build.**

Run: `npm test -- design_system_contract.spec.ts`; `npm test`; `npm run build`.

Expected: all tests pass and Vite produces the web artifact.

- [ ] **Step 3: Inspect changed file sizes and deploy web-only after a browser screenshot comparison.**

The deployment is web-only; do not restart API, LiveKit, PostgreSQL or proxy. Attach runtime evidence that distinguishes browser visual comparison from health checks.

**Current constraint:** the automated environment has no authenticated browser surface for a truthful in-app screenshot. A web-only runtime release may be smoke-tested independently, but this checkbox remains open until a signed-in browser comparison is recorded.

## Self-review

- **Coverage:** Targets the exact structural mismatch reported by the user: header, message rhythm, composer, voice-room, stream and shell/dock geometry.
- **Preservation:** Uses no fixture people or mock media; stores, server ACL, actual stream selection and attachment calls are untouched.
- **Limit:** Profile/reset/admin screens absent from the existing frontend remain out of this visual-layout packet rather than being invented as non-functional routes.
