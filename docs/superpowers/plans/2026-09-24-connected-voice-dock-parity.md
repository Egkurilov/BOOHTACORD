# Connected VoiceDock Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the persistent connected VoiceDock match the compact status/channel/control hierarchy of the GuildChat `voice-1440.png` and C-18 without changing media admission or publishing behavior.

**Architecture:** Keep `VoiceDock.vue` as the single owner of dock state and four controls. Move its existing paint rules from crowded `voice.css` to `voice_dock.css`, then present one short truthful status, a selectable active-channel name, and four 40px actions. Route return-to-room through the existing `selectChannel` action; route screen-share stop through the existing `voiceConnection.stopScreen` action.

**Tech Stack:** Vue 3, TypeScript, CSS, Vitest SSR, Vite.

---

## Scope and files

- Slavik Gym route `split_first`, leaf T-050 / DS-T06 connected VoiceDock presentation; `structure_no_rg` until the exact leaf is selected.
- Source: `GuildChat_Design_System_v1.0.zip` C-18 and `reference/screenshots/voice-1440.png`. The preview's synthetic occupants, guild name and media bitrate are not runtime data.
- Create `frontend/src/voice/voice_dock_reference.spec.ts` and `frontend/src/design/voice_dock.css`.
- Modify `frontend/src/voice/VoiceDock.vue`, `frontend/src/workspace/WorkspaceApp.vue`, `frontend/src/design/voice.css`, `frontend/src/design/responsive_shell.css`, `frontend/src/style.css`, `docs/design/GUILDCHAT_V1_TODO.md`, and `docs/design/GUILDCHAT_V1_STATUS.md`.
- Preserve existing four control effects, persistent dock across DM navigation, 48px idle / 116px connected minimum heights, and all permission/reconnect distinctions. Do not add a fifth fake audio control or measured bitrate.
- Shared worktree contains unrelated edits; do not stage or deploy this leaf independently.

### Task 1: Lock rendered behavior before code

- [ ] **Step 1: Add the failing SSR contract.** Create `frontend/src/voice/voice_dock_reference.spec.ts`:

```ts
import { describe, expect, it } from 'vitest'
import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import VoiceDock from './VoiceDock.vue'

const channel = { id: 'voice-1', name: 'game-audio-poc', kind: 'VOICE' as const, position: 0, admissionClosed: false }
const props = { channel, activationMode: 'VAD' as const, deafened: false, deafenChanging: false, microphoneMuted: false, microphonePermissionDenied: false, screenState: 'IDLE' as const, state: 'CONNECTED' as const }
const render = (overrides: Record<string, unknown>) => renderToString(createSSRApp(VoiceDock, { ...props, ...overrides }))

describe('GuildChat connected VoiceDock', () => {
  it('has a compact idle state without call controls', async () => {
    const html = await render({ channel: null, state: 'IDLE' })
    expect(html).toContain('Не в голосовом канале')
    expect(html).not.toContain('voice-actions')
  })
  it('shows a short status, a return-to-room control and exactly four actions', async () => {
    const html = await render({})
    expect(html).toContain('В канале')
    expect(html).toContain('game-audio-poc')
    expect(html).toContain('Вернуться в голосовой канал')
    for (const id of ['voice-mic', 'voice-deafen', 'voice-share', 'voice-leave']) expect(html).toContain(`data-testid="${id}"`)
    expect((html.match(/class="voice-icon-button/g) ?? []).length).toBe(4)
    expect(html).not.toContain('Вы можете открыть другой канал')
  })
  it('makes deafen, listener, reconnect and screen-sharing states explicit', async () => {
    expect(await render({ deafened: true })).toContain('Звук и микрофон выключены')
    expect(await render({ state: 'LISTENER', microphonePermissionDenied: true })).toContain('Режим слушателя')
    expect(await render({ state: 'RECONNECTING' })).toContain('Восстанавливаем связь')
    expect(await render({ screenState: 'SHARING' })).toContain('Остановить демонстрацию экрана')
  })
})
```

Run `npm test -- voice_dock_reference.spec.ts` in `frontend`; expect the connected cases to fail before implementation.

### Task 2: Implement one truthful dock surface

- [ ] **Step 2: Move and restyle the dock CSS.** Remove the complete `.voice-dock` through `.voice-icon` rule family from `frontend/src/design/voice.css`. Create `frontend/src/design/voice_dock.css` with the same token-based 40px controls, these layout rules, and focused status variants:

```css
.voice-dock { min-height: 48px; border-top: 1px solid var(--gc-border-subtle); padding: var(--gc-space-3); background: var(--gc-surface); }
.voice-dock.connected { display: flex; min-height: var(--gc-layout-voice-dock); flex-direction: column; justify-content: center; }
.voice-dock-idle { margin: 0; color: var(--gc-text-muted); font-size: var(--gc-text-caption); }
.voice-dock-copy { min-width: 0; }
.voice-dock-header { display: flex; min-width: 0; align-items: center; gap: var(--gc-space-2); color: var(--gc-success); }
.voice-dock-header.is-warning { color: var(--gc-warning); }
.voice-status { min-width: 0; overflow: hidden; margin: 0; font-size: var(--gc-text-caption); text-overflow: ellipsis; white-space: nowrap; }
.voice-dock-channel { display: block; max-width: calc(100% - 24px); overflow: hidden; margin: var(--gc-space-1) 0 var(--gc-space-2) 24px; border: 0; padding: 0; color: var(--gc-text-primary); background: transparent; font-size: var(--gc-text-small); text-align: left; text-overflow: ellipsis; white-space: nowrap; cursor: pointer; }
.voice-dock-channel:hover { text-decoration: underline; }
.voice-dock-channel:focus-visible { outline: 2px solid var(--gc-focus); outline-offset: 3px; }
.voice-actions { display: flex; justify-content: space-between; gap: var(--gc-space-2); }
.voice-icon-button { display: grid; width: var(--gc-size-control); height: var(--gc-size-control); place-items: center; border: 0; border-radius: var(--gc-radius-sm); color: var(--gc-text-secondary); background: var(--gc-surface-raised); }
.voice-icon-button:hover:not(:disabled), .voice-icon-button[aria-pressed=true] { color: var(--gc-text-primary); background: var(--gc-surface-hover); }
.voice-icon-button.is-muted { color: var(--gc-danger); background: var(--gc-danger-bg); }
.voice-icon-button.is-sharing { color: var(--gc-success); background: var(--gc-success-bg); }
.voice-icon-button.voice-icon-button--danger { color: var(--gc-danger); }
.voice-icon-button:disabled { color: var(--gc-text-disabled); }
.voice-icon { width: var(--gc-size-icon); height: var(--gc-size-icon); fill: none; stroke: currentColor; stroke-linecap: round; stroke-linejoin: round; stroke-width: 1.75; }
```

Import it from `frontend/src/style.css` after `voice.css`. In `frontend/src/design/responsive_shell.css`, replace the obsolete `.mobile-voice-dock .voice-hint` selector with `.mobile-voice-dock .voice-dock-copy { min-width: 0; }`; keep `.voice-actions` on grid column 2 below 1024 CSS px.

- [ ] **Step 3: Change the dock copy and controls.** In `VoiceDock.vue`, use `const props = defineProps<...>()` and a computed `statusText` ordered as `RECONNECTING`, `LEAVING`, `deafened`, `LISTENER`/permission-denied, then `В канале`. Render `voice-dock-idle` only with no channel; render `voice-dock-copy` with `voice-dock-header` and `voice-dock-channel` when connected. The channel button emits `returnToRoom`; add `screenState: ScreenShareState` and `stopScreen: []`. Add the four C-18 test IDs. Mic/deafen icon paths and `.is-muted` class must reflect their actual state; share button emits `stopScreen` and says `Остановить демонстрацию экрана` only when `screenState === 'SHARING'`, otherwise emits `startScreen`, disabled during `STARTING`, `RECONNECTING` and `LEAVING`. Keep microphone/PTT and deafen disable conditions. Keep `aria-pressed` truthful.

- [ ] **Step 4: Wire existing actions only.** In `WorkspaceApp.vue`, add `function returnToVoiceRoom(): void { if (activeVoiceChannel.value) selectChannel(activeVoiceChannel.value) }`. Pass `:screen-state="voiceConnection.screenState"`, `@return-to-room="returnToVoiceRoom"`, and `@stop-screen="voiceConnection.stopScreen"` to `VoiceDock`. Do not change `startScreen` or `leaveVoice` implementation.

### Task 3: Validate and record remaining design work

- [ ] **Step 5: Verify nearest and full checks.** Run focused `npm test -- voice_dock_reference.spec.ts`, full `npm test`, `npm run build`, `pwsh -NoProfile -File scripts/verify-spec-traceability.ps1`, and `git diff --check`. Confirm `VoiceDock.vue`, `voice_dock.css` and `voice.css` stay under 120 lines. Inspect `git status --short`; do not stage unrelated work.
- [ ] **Step 6: Update status docs.** Under DS-T06, record compact two-line dock and active-channel return as locally implemented; in `GUILDCHAT_V1_STATUS.md`, note production still uses the older bundle and visual acceptance is open. Keep DS-T06 `PARTIAL` and do not claim a real media POC or a 1:1 release.

## Self-review

C-18 has four controls, not five. The preview's synthetic channel/name and bitrate are examples, so actual channel and connection state remain data-derived. Existing voice/media actions are reused; the only new navigation event selects an already-known topology channel. No product acceptance is closed by SSR or build checks. The persistent user session and unrelated dirty files are untouched. Execution is inline under the existing user goal because no subagent is requested; commit and deployment remain separate review-gated work.
