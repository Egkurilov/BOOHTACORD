# Stream Toolbar Reference Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the selected-stream control row match the supplied `stream-1440.png` composition: target/actual quality and game volume below the large video stage, with secondary actions outside that row.

**Architecture:** Keep `ScreenViewer.vue` as the media controller and preserve its existing events and refs. Reposition only the window-expansion action into the bottom return bar, make diagnostics a compact accessible disclosure, and adjust the existing CSS. The browser fullscreen button stays on the stage.

**Tech Stack:** Vue 3, CSS, Vitest, Vite.

---

### Task 1: Compact selected-stream toolbar

**Files:**
- Create: `frontend/src/voice/screen_viewer_toolbar_layout.spec.ts`
- Modify: `frontend/src/voice/ScreenViewer.vue`
- Modify: `frontend/src/design/voice_viewer_reference.css`
- Modify: `frontend/src/voice/screen_viewer_reference.spec.ts`
- Modify: `docs/design/GUILDCHAT_V1_TODO.md`

- [x] **Step 1: Write the failing layout contract.** The new `screen_viewer_toolbar_layout.spec.ts` slices the template at `stream-quality-row` and `stream-voice-return`, checks that expansion is only in the latter, and verifies horizontal quality CSS.

```ts
const row = viewer.slice(viewer.indexOf('class="stream-quality-row"'), viewer.indexOf('class="screen-rail-section"'))
const footer = viewer.slice(viewer.indexOf('class="stream-voice-return"'))
expect(row).not.toContain('screen-window-toggle')
expect(footer).toContain('v-if="selectedStream || expanded" class="screen-window-toggle')
```

- [x] **Step 2: Run `npm test -- screen_viewer_toolbar_layout.spec.ts` in `frontend`.** Both new tests failed before implementation, as expected.
- [x] **Step 3: Patch `ScreenViewer.vue` without exceeding its 120-line hard limit.** Diagnostics summary retains a screen-reader label; the expansion button is in the footer. The `expanded` guard preserves a way back if the stream ends during expansion.

```html
<summary title="Нет свежих данных"><span class="stream-diagnostics-badge" aria-hidden="true"></span><span class="gc-sr-only">Нет свежих данных</span></summary>
<button v-if="selectedStream || expanded" class="screen-window-toggle gc-button gc-button--secondary" type="button" :aria-pressed="expanded" @click="emit('update:expanded', !expanded)">{{ expanded ? 'Вернуть в окно канала' : 'Развернуть на всю область' }}</button>
```

- [x] **Step 4: Patch `voice_viewer_reference.css`.** The control row is 40px minimum, quality labels are distributed horizontally, diagnostics summary is 32×32px, and rows wrap below 1100px.

```css
.stream-quality-row { display: flex; min-height: 40px; align-items: center; gap: var(--gc-space-3); padding: 0; }
.stream-quality { display: flex; min-width: 0; flex: 1; align-items: center; justify-content: space-between; gap: var(--gc-space-4); color: var(--gc-text-muted); font-size: var(--gc-text-caption); }
.stream-diagnostics > summary { display: grid; width: 32px; height: 32px; place-items: center; border: 1px solid var(--gc-border-subtle); border-radius: var(--gc-radius-sm); padding: 0; cursor: pointer; list-style: none; }
@media (max-width: 1100px) { .stream-quality-row, .stream-quality, .stream-voice-return { flex-wrap: wrap; } }
```

- [x] **Step 5: Update the existing zoom test and the DS-T07 note.** The test now checks wrapping of the quality row and footer; the design TODO remains PARTIAL pending an authenticated screenshot.
- [x] **Step 6: Run native checks.** Targeted tests, 75 files / 226 frontend tests, typecheck/build, file line-count ratchet and `git diff --check` passed. Screenshot acceptance remains open.

## Self-review

This leaf changes only visual placement. It does not invent actual FPS, remove quality diagnostics, change audio subscription, alter fullscreen semantics, or claim screenshot acceptance without a connected browser capture.
