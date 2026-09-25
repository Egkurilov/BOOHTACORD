# Voice prejoin joining copy implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the voice prejoin card announce an in-progress join instead of presenting the idle instruction throughout JOINING.

**Architecture:** Keep the state-dependent wording in the `VoicePrejoin.vue` leaf. Use its existing `voiceState` prop so the heading and helper text update together; expose the heading as a polite live region.

**Tech Stack:** Vue 3, TypeScript, Vitest SSR, Vite.

---

### Task 1: Joining copy and semantics

**Files:**
- Modify: `frontend/src/voice/VoicePrejoin.vue`
- Create: `frontend/src/voice/voice_prejoin_joining_copy.spec.ts`

- [x] Add SSR tests that expect the JOINING card to describe connection in progress and the IDLE card to retain its join invitation.
- [x] Run `npm test -- voice_prejoin_joining_copy.spec.ts` and confirm the JOINING test fails on the current component.
- [x] Change the h3/helper copy by `voiceState` and place `aria-live="polite" aria-atomic="true"` on the heading.
- [x] Run the focused test, full `npm test`, and `npm run build`.
- [x] Record local native evidence and any browser/real-media limitations without closing DES-07 or QA-07.
