# GuildChat PNG Shell Geometry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align the 1440 CSS px application shell with the supplied chat/voice/stream PNG compositions: 280px navigation, 248px chat roster and no outer frame, without copying the demo-only preview toolbar or fixture data.

**Architecture:** Make a documented visual exception to the Markdown grid values only at the wide breakpoint. Keep existing 1280/1024/mobile breakpoints and ADR-008's voice/stream member drawer. Derive viewport arithmetic in focused tests from the CSS tokens.

**Tech Stack:** Vue 3, CSS custom properties, Vitest, Vite.

---

## Route and files

- Slavik Gym route: `small_direct`; selected leaf: backlog T-050 / design DS-T03 adaptive shell.
- Runtime edge: `WorkspaceApp.vue` → `.app-frame` / `.gc-shell` in `shell.css` → `tokens.css`; ADR-008's voice-stage override remains in `responsive_shell.css`.
- Modify `frontend/src/design/tokens.css` for wide layout values only.
- Modify `frontend/src/design/shell.css` for the wide outer frame, shell height and border.
- Create `frontend/src/design/shell_reference_geometry.spec.ts` for PNG horizontal geometry.
- Modify `frontend/src/design/design_system_contract.spec.ts` and `frontend/src/voice/voice_grid_reference.spec.ts` to reflect the ADR exception.
- Create `docs/adr/ADR-009-png-shell-geometry.md`; modify `docs/design/GUILDCHAT_V1_STATUS.md` and `docs/design/GUILDCHAT_V1_TODO.md`.
- Do not touch media, roster data, authentication, chat messages or deployment in this packet.

### Task 1: Failing reference geometry tests

- [x] **Step 1: Update token expectations and add the layout calculation.** In `design_system_contract.spec.ts`, replace the 312px assertions with `--gc-layout-nav-wide: 280px`, `--gc-layout-aside-wide: 248px`, and add `--gc-layout-frame-wide: 0px`. Create `shell_reference_geometry.spec.ts` with:

```ts
import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const tokens = readFileSync(new URL('./tokens.css', import.meta.url), 'utf8')
const shell = readFileSync(new URL('./shell.css', import.meta.url), 'utf8')
function token(name: string): number {
  const value = tokens.match(new RegExp(`--gc-${name}:\\s*(\\d+)px;`))?.[1]
  if (!value) throw new Error(`Missing layout token: ${name}`)
  return Number(value)
}

describe('1440px PNG shell geometry', () => {
  it('keeps the chat and voice content at the screenshot x coordinates', () => {
    const wideRule = shell.match(/@media \(min-width: 1440px\) \{([\s\S]*?)\n\}/)?.[1] ?? ''
    const wideNav = token('layout-nav-wide')
    const wideAside = token('layout-aside-wide')
    const wideFrame = token('layout-frame-wide')
    expect([wideFrame, wideNav, wideAside]).toEqual([0, 280, 248])
    expect(1440 - 2 * wideFrame - wideNav - wideAside).toBe(912)
    expect(1440 - 2 * wideFrame - wideNav).toBe(1160)
    expect(wideRule).toContain('height: 100dvh')
    expect(wideRule).toContain('border: 0')
    expect(wideRule).toContain('border-radius: 0')
    expect(wideRule).toContain('.members { display: block; padding: var(--gc-space-6) var(--gc-space-4); }')
    expect(shell).toContain('@media (min-width: 1280px) and (max-width: 1439px)')
  })
})
```

Do not encode the 52px preview toolbar as runtime UI.

- [x] **Step 2: Update the voice-grid calculation before implementation.** In `voice_grid_reference.spec.ts`, compute the wide shell border as zero and medium/small border as one pixel per side:

```ts
const border = viewport >= 1440 ? 0 : 1
const usable = viewport - 2 * token(frame) - 2 * border - token(nav) - 2 * token('space-6')
```

Then assert the resulting wide card width is between 174px and 176px while retaining six/five/four columns at 1440/1280/1024.

- [x] **Step 3: Run the focused tests before implementation.** From `frontend`, run `npm test -- shell_reference_geometry.spec.ts design_system_contract.spec.ts voice_grid_reference.spec.ts`. Expected: FAIL on the old 312/312/24 wide values and wide border.

### Task 2: Wide-shell CSS and decision record

- [x] **Step 4: Apply the visual CSS exception.** In `tokens.css` set the three wide values to `280px`, `248px`, `0px`. In `shell.css`, use this 1440+ rule while leaving the 1280/1024 rules unchanged:

```css
@media (min-width: 1440px) {
  .app-frame { padding: var(--gc-layout-frame-wide); }
  .gc-shell { min-height: 0; height: 100dvh; grid-template-columns: var(--gc-layout-nav-wide) minmax(0, 1fr) var(--gc-layout-aside-wide); border: 0; border-radius: 0; box-shadow: none; }
  .gc-shell.no-aside { grid-template-columns: var(--gc-layout-nav-wide) minmax(0, 1fr); }
  .members { display: block; padding: var(--gc-space-6) var(--gc-space-4); }
}
```

- [x] **Step 5: Record the conflict and status.** `ADR-009` must state that PNG horizontal composition is authoritative for 1440+ application content, whereas the Markdown 24/312/312 grid remains the original contract and 1280/1024 values remain unchanged. The preview toolbar and synthetic content are not product UI. Update the status table to 0/280/248 with a link to ADR-009, and leave DS-T03/11 `PARTIAL` pending authenticated screenshots and zoom checks.

- [x] **Step 6: Validate.** Run the focused tests, `npm test`, `npm run build`, `pwsh -NoProfile -File scripts/verify-spec-traceability.ps1`, and `git diff --check`. Inspect changed line counts and `git status --short`. Do not stage or push the existing mixed dirty worktree.

## Self-review

This packet changes only the wide shell's horizontal and outer-frame composition. It preserves user-facing controls, real-data sourcing, and narrower breakpoints. Vertical header, VoiceDock placement, and connected production screenshot acceptance remain separate named leaves; the claim of full 1:1 parity remains open.
