# Six-column voice grid implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render six voice participant cards per row at 1440 CSS px, as in `reference/screenshots/voice-1440.png`, without shrinking cards below 160px or changing media behavior.

**Architecture:** Keep the existing wide voice stage from ADR-008 and the normative 24px frame/312px navigation. Change only the participant-grid gap from 16px to the 12px spacing token. A focused test derives available width from shell tokens and asserts the resulting 1440/1280/1024 column counts.

**Tech Stack:** Vue 3 CSS, Vitest, Vite.

---

## Route and ownership

- Slavik Gym route: `small_direct`; selected leaf: T-050 / DS-T06 voice-room participant grid.
- Exact runtime edge: `WorkspaceApp.vue` wide voice shell → `ConversationPane.vue` room → `VoiceParticipantVolumes.vue` → `voice.css` participant grid.
- Preserve user data, admission, LiveKit state, the text-channel three-column shell, and the existing minimum card width.
- No production deploy or pixel-parity claim in this packet. The PNG and Markdown shell geometry conflict remains separate.

### Task 1: Six-card desktop grid

**Files:**
- Create: `frontend/src/voice/voice_grid_reference.spec.ts`
- Modify: `frontend/src/design/voice.css`
- Modify: `docs/design/GUILDCHAT_V1_TODO.md`

- [x] **Step 1: Add the failing grid contract.** Read `voice.css`, `shell.css`, and `tokens.css`; assert the participant grid retains `minmax(160px, 1fr)` and uses `gap: var(--gc-space-3)`. The focused test must calculate the column count from production tokens:

```ts
const token = (name: string) => Number(tokens.match(new RegExp(`--gc-${name}:\\s*(\\d+)px;`))?.[1])
const rule = voice.match(/\.participant-grid, \.voice-participant-volumes \{([^}]+)\}/)?.[1] ?? ''
const minCard = Number(rule.match(/minmax\((\d+)px,\s*1fr\)/)?.[1])
const gapName = rule.match(/gap: var\(--gc-(space-\d+)\)/)?.[1] ?? ''
const columns = (viewport: number, frame: string, nav: string) => {
  const usable = viewport - 2 * token(frame) - 2 - token(nav) - 2 * token('space-6')
  const gap = token(gapName)
  return Math.floor((usable + gap) / (minCard + gap))
}
expect(rule).toContain('gap: var(--gc-space-3)')
expect(minCard).toBe(160)
expect(columns(1440, 'layout-frame-wide', 'layout-nav-wide')).toBe(6)
expect(columns(1280, 'layout-frame-medium', 'layout-nav-medium')).toBe(5)
expect(columns(1024, 'layout-frame-medium', 'layout-nav-small')).toBe(4)
```

The test also asserts `.room-wrap` uses `padding: var(--gc-space-6)` and the desktop shell has a 1px border, so the arithmetic stays attached to the real CSS.
- [x] **Step 2: Verify the test fails.** Run `npm test -- voice_grid_reference.spec.ts` from `frontend`. Expected: the grid still uses `--gc-space-4` (16px).
- [x] **Step 3: Apply the minimal CSS change.** In the existing `.participant-grid, .voice-participant-volumes` rule, replace `gap: var(--gc-space-4)` with `gap: var(--gc-space-3)`; do not change card width or unrelated participant styles:

```css
.participant-grid, .voice-participant-volumes { display: grid; grid-template-columns: repeat(auto-fill, minmax(160px, 1fr)); gap: var(--gc-space-3); }
```
- [x] **Step 4: Verify.** Run the focused test, `npm test`, and `npm run build`; expect all to pass. Run `git diff --check` and inspect changed file sizes.
- [x] **Step 5: Record status.** Add this sentence to DS-T06 in `GUILDCHAT_V1_TODO.md`: `На 1440 CSS px сетка локально рассчитана на шесть карточек в строке; production-скриншот подключённой комнаты ещё не получен.` Do not claim 1:1 or deploy this mixed worktree.

## Self-review

This plan covers one visual discrepancy found in the reference audit. It does not resolve the screenshot-versus-Markdown shell width conflict, the lower voice-exit placement conflict, or authenticated browser acceptance; those remain explicit follow-up leaves.
