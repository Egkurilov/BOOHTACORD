# Connected Voice Room Footer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Match the connected voice room's fixed lower status-and-leave bar from `voice-1440.png` while keeping the persistent VoiceDock, truthful state and responsive layouts.

**Architecture:** Extract the unchanged pre-join card from the 120-line `ConversationPane.vue` into one leaf component, then add a connected-only footer component below the scrollable participant grid. Pass the existing `leaveVoice` action down from `WorkspaceApp`; the footer calls the same action as VoiceDock. Show the footer from 1024 CSS px, including the observed 1256 CSS px production viewport; below 1024 CSS px the permanent dock becomes the compact bottom bar.

**Tech Stack:** Vue 3, TypeScript, CSS, Vitest, Vite.

---

## Route and exact files

- Slavik Gym route: `split_first`; selected leaf: backlog T-050 / DS-T06 connected voice-room presentation.
- Runtime edge: `WorkspaceApp.vue` (`leaveVoice`, `voiceActivation.mode`) → `WorkspaceMain.vue` → `ConversationPane.vue` → `VoiceRoomFooter.vue`.
- Pre-join behavior moves unchanged from `ConversationPane.vue` to `VoicePrejoin.vue`; events remain `join(channelId, transfer?, joinMode?)` and `transfer(channelId)`.
- Create `frontend/src/voice/VoicePrejoin.vue`, `frontend/src/voice/VoiceRoomFooter.vue`, `frontend/src/design/voice_room_footer.css`, and `frontend/src/voice/voice_room_footer_reference.spec.ts`.
- Modify `frontend/src/conversation/ConversationPane.vue`, `frontend/src/workspace/WorkspaceMain.vue`, `frontend/src/workspace/WorkspaceApp.vue`, `frontend/src/style.css`, `frontend/src/voice/disconnected_voice_presentation.spec.ts`, and design status/TODO docs. SSR assertions need `@types/node` in the frontend dev dependencies; `App.vue` must keep its `window.setInterval` handle typed as `number` when those ambient types are present.
- Do not change backend, media admission, LiveKit tracks, persistent VoiceDock, or screen viewer.

### Task 1: Preserve pre-join behavior and free the crowded pane

- [x] **Step 1: Write a failing extraction test.** In `disconnected_voice_presentation.spec.ts`, keep the existing `source()` helper and replace the test body with:

```ts
const pane = source('../conversation/ConversationPane.vue')
const prejoin = source('./VoicePrejoin.vue')
const styles = source('../design/voice.css')
expect(pane).toContain('<VoicePrejoin')
for (const text of ['voice-prejoin-title', 'Подключиться к голосу', 'Подключиться без микрофона', 'Перенести подключение', 'voiceError', "voiceState === 'JOINING'"]) expect(prejoin).toContain(text)
expect(styles).toContain('.voice-prejoin {')
expect(styles).toContain('.voice-prejoin-card {')
```

Run `npm test -- disconnected_voice_presentation.spec.ts` in `frontend`; expected FAIL because the child does not exist.

- [x] **Step 2: Extract the original markup.** `VoicePrejoin.vue` owns this exact interface and actions:

```vue
<script setup lang="ts">
import type { VoiceConnectionState } from './connection_store'
import type { VoiceJoinMode } from './livekit_gateway'

defineProps<{ channelId: string; voiceError: string | null; voiceState: VoiceConnectionState; voiceTransferRequired: boolean }>()
const emit = defineEmits<{ join: [channelId: string, transfer?: boolean, joinMode?: VoiceJoinMode]; transfer: [channelId: string] }>()
</script>

<template>
  <div class="voice-prejoin">
    <article class="voice-prejoin-card" aria-labelledby="voice-prejoin-title">
      <span class="voice-prejoin-icon" aria-hidden="true"><svg viewBox="0 0 24 24"><path d="M12 3a3 3 0 0 0-3 3v5a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3Zm-7 8a7 7 0 0 0 14 0M12 18v3m-4 0h8" /></svg></span>
      <p class="eyebrow">ГОЛОСОВАЯ КОМНАТА</p>
      <h3 id="voice-prejoin-title">Вы не подключены</h3>
      <p class="voice-prejoin-copy">Подключитесь, чтобы увидеть участников комнаты и статусы микрофонов.</p>
      <p v-if="voiceError" class="state state-error" role="alert">{{ voiceError }}</p>
      <div class="voice-prejoin-actions">
        <button v-if="voiceTransferRequired" class="gc-button gc-button--secondary" type="button" @click="emit('transfer', channelId)">Перенести подключение</button>
        <button class="gc-button gc-button--primary" type="button" :disabled="voiceState === 'JOINING'" @click="emit('join', channelId)">{{ voiceState === 'JOINING' ? 'Подключаемся…' : 'Подключиться к голосу' }}</button>
        <button class="gc-button gc-button--secondary" type="button" :disabled="voiceState === 'JOINING'" @click="emit('join', channelId, false, 'listener')">Подключиться без микрофона</button>
      </div>
    </article>
  </div>
</template>
```

Replace the original `v-else` block in `ConversationPane.vue` with the exact forwarding edge below. Rerun the focused pre-join test; expected PASS.

```vue
<VoicePrejoin v-else :channel-id="channel.id" :voice-error="voiceError" :voice-state="voiceState" :voice-transfer-required="voiceTransferRequired" @join="(id, transfer, mode) => emit('join', id, transfer, mode)" @transfer="emit('transfer', $event)" />
```

### Task 2: Add the contextual connected footer

- [x] **Step 3: Write a failing footer contract.** Create `voice_room_footer_reference.spec.ts` with:

```ts
import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

function source(path: string): string {
  try { return readFileSync(new URL(path, import.meta.url), 'utf8') }
  catch { return '' }
}

describe('connected voice-room reference footer', () => {
  it('uses truthful connection copy and one contextual leave control', () => {
    const footer = source('./VoiceRoomFooter.vue')
    for (const text of ['Вы подключены к', 'Выйти из канала', 'Режим слушателя', 'Восстанавливаем', "state === 'LEAVING'", "emit('leave')"]) expect(footer).toContain(text)
    expect(footer).not.toContain('128 кбит/с')
  })
  it('wires the existing leave action and only displays the bar for the open connected room', () => {
    expect(source('../conversation/ConversationPane.vue')).toContain('<VoiceRoomFooter v-if="voiceIsActive && !selectedScreenStreamId && !screenViewerEnded"')
    expect(source('../workspace/WorkspaceMain.vue')).toContain('@leave="leaveVoice"')
    expect(source('../workspace/WorkspaceApp.vue')).toContain(':leave-voice="leaveVoice"')
    expect(source('../style.css')).toContain("@import './design/voice_room_footer.css';")
    expect(source('../design/voice_room_footer.css')).toContain('@media (min-width: 1024px)')
  })
})
```

Run the focused test; expected FAIL before implementation.

- [x] **Step 4: Implement the status component.** Create `VoiceRoomFooter.vue` with this complete component. The icon is decorative; the text is the button's accessible name. Do not copy the preview's unmeasured 128 кбит/с value.

```vue
<script setup lang="ts">
import { computed } from 'vue'
import type { VoiceActivationMode } from './activation_store'
import type { VoiceConnectionState } from './connection_store'

const props = defineProps<{ channelName: string; state: VoiceConnectionState; activationMode: VoiceActivationMode }>()
const emit = defineEmits<{ leave: [] }>()
const status = computed(() => props.state === 'RECONNECTING' ? `Восстанавливаем связь с «${props.channelName}»` : props.state === 'LEAVING' ? 'Завершаем голосовое подключение…' : props.state === 'ERROR' ? 'Ошибка голосового подключения' : `Вы подключены к «${props.channelName}»`)
const hint = computed(() => props.state === 'LISTENER' ? 'Режим слушателя · микрофон не передаётся' : props.activationMode === 'PTT' ? 'Нажми и говори' : 'Автоактивация голосом')
</script>

<template>
  <footer class="voice-room-footer" aria-label="Голосовое подключение" data-testid="voice-room-footer">
    <div class="voice-room-footer-copy"><p>{{ status }}</p><small>{{ hint }}</small></div>
    <button class="gc-button gc-button--secondary" type="button" :disabled="state === 'LEAVING'" @click="emit('leave')"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 15c4.8-4.3 13.2-4.3 18 0l-2 3-3-1.5v-2.2a13 13 0 0 0-8 0v2.2L5 18z" /></svg><span>Выйти из канала</span></button>
  </footer>
</template>
```

- [x] **Step 5: Wire the existing leave action.** Add `activationMode: VoiceActivationMode` and `leaveVoice: WorkspaceVoiceControls['leaveVoice']` to `WorkspaceMain.vue`, pass `:activation-mode="voiceActivation.mode" :leave-voice="leaveVoice"` from `WorkspaceApp.vue`, and add `activationMode: VoiceActivationMode` plus `leave: []` to the `ConversationPane.vue` props/emits. After `.room-wrap`, render:

```vue
<VoiceRoomFooter v-if="voiceIsActive && !selectedScreenStreamId && !screenViewerEnded" :activation-mode="activationMode" :channel-name="channel.name" :state="voiceState" @leave="emit('leave')" />
```

In `WorkspaceMain.vue`, pass `:activation-mode="activationMode"` to the pane and forward `@leave="leaveVoice"`. Do not create a second lease release path.

- [x] **Step 6: Style the reference placement.** Import `voice_room_footer.css` from `style.css`. Use a 76px min-height, top border, 24px horizontal padding, left status/hint and right secondary leave button. Apply `display: flex` at `min-width:1024px`; below that, VoiceDock remains the sole visible disconnect control in the compact bottom bar. Leave screen viewer and its return bar unchanged.

```css
.voice-room-footer { display: none; flex: 0 0 auto; min-height: 76px; align-items: center; justify-content: space-between; gap: var(--gc-space-4); border-top: 1px solid var(--gc-border-subtle); padding: var(--gc-space-3) var(--gc-space-6); }
.voice-room-footer-copy { display: grid; gap: var(--gc-space-1); min-width: 0; }
.voice-room-footer-copy p, .voice-room-footer-copy small { overflow: hidden; margin: 0; text-overflow: ellipsis; white-space: nowrap; }
.voice-room-footer-copy p { color: var(--gc-text-secondary); font-size: var(--gc-text-body); }
.voice-room-footer-copy small { color: var(--gc-text-muted); font-size: var(--gc-text-caption); }
.voice-room-footer .gc-button { flex: 0 0 auto; }
.voice-room-footer .gc-button svg { width: 16px; height: 16px; fill: none; stroke: currentColor; stroke-linecap: round; stroke-linejoin: round; stroke-width: 1.7; }
@media (min-width: 1024px) { .voice-room-footer { display: flex; } }
```

### Task 3: Validate and document

- [x] **Step 7: Run native checks.** Run the two focused voice tests, `npm test`, `npm run build`, `pwsh -NoProfile -File scripts/verify-spec-traceability.ps1`, and `git diff --check`. Inspect changed file sizes; `ConversationPane.vue` must be under 120 lines.

- [x] **Step 8: Update design status.** In `GUILDCHAT_V1_TODO.md`, record the local contextual footer under DS-T06 and replace the inaccurate C-18 blocker under DS-T11: C-19 forbids repeating four voice controls in UserFooter, not a contextual leave action in the voice room. In `GUILDCHAT_V1_STATUS.md`, note the footer remains unverified in a connected production screenshot. Do not mark design acceptance complete or deploy this mixed worktree.

## Self-review

The footer is a single contextual control; VoiceDock remains persistent across navigation. It uses existing confirmed connection state and does not fabricate bitrate, capacity or media diagnostics. The 64px wide-header versus 72px Markdown conflict remains a separate ADR/test/CSS leaf.
