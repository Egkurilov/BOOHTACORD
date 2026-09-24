# Voice and Stream Wide Stage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the joined voice room and selected stream the full central width shown in the supplied `voice-1440.png` and `stream-1440.png`, while keeping the confirmed member roster reachable.

**Architecture:** The text conversation retains the three-column GuildChat shell. A selected voice channel uses a two-column shell at desktop widths; its member panel becomes a bounded overlay opened by the existing header action. No media, admission, or roster data flow changes.

**Tech Stack:** Vue 3, CSS, Vitest, Vite.

---

### Task 1: Wide voice/stream stage

**Files:**
- Modify: `frontend/src/design/design_fidelity.spec.ts`
- Modify: `frontend/src/workspace/WorkspaceApp.vue`
- Modify: `frontend/src/design/responsive_shell.css`
- Create: `docs/adr/ADR-008-voice-stage-layout.md`
- Modify: `docs/design/GUILDCHAT_V1_TODO.md`

- [x] **Step 1: Write a failing source-level test for the view-specific shell.** In `design_fidelity.spec.ts`, assert that `WorkspaceApp.vue` defines `voiceStageWide` from `selectedChannel.value?.kind === 'VOICE'`, binds it to `voice-stage-wide` and `no-aside`, and that `responsive_shell.css` contains `.gc-shell.voice-stage-wide .members.is-open` and `.gc-shell.voice-stage-wide .workspace-header-toggle--members`.
- [x] **Step 2: Run `npm test -- design_fidelity.spec.ts` in `frontend`; the new test failed because `voiceStageWide` was absent.**
- [x] **Step 3: Add the Vue computed state and class binding.** Added `const voiceStageWide = computed(() => selectedChannel.value?.kind === 'VOICE' && !selectedDirectMessage.value && activePanel.value === 'none')` after the selected DM computed value. Bound `voice-stage-wide: voiceStageWide` and included `voiceStageWide` in the `no-aside` condition on `gc-shell`.
- [x] **Step 4: Style the desktop overlay.** At `min-width:1280px`, `.gc-shell.voice-stage-wide .members` is hidden until `.is-open`, positioned absolutely on the right with width `min(320px, calc(100% - 32px))`; the existing header action and scrim are visible when needed. The 1024–1279 and mobile drawer rules are unchanged.
- [x] **Step 5: Record the visual decision.** `ADR-008` records the voice/stream PNG composition, accessible member drawer, and unchanged three-column text channel. The design TODO still requires connected screenshots.
- [x] **Step 6: Run `npm test -- design_fidelity.spec.ts`, `npm test`, and `npm run build` in `frontend`.** Final result: 74 files / 224 tests PASS, typecheck/build PASS. Changed files are under the 120-line hard ratchet; `git diff --check` has no whitespace error. Screenshot acceptance remains open.

## Self-review

This plan changes only the visual composition of a selected voice channel, including selected-stream view. It preserves the one-guild shell, VoiceDock, media state, roster source and browser accessibility action. The remaining screen-viewer control-row differences and authenticated screenshot acceptance are separate follow-up leaves.
