# Voice PTT keyboard capture implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow Tab to leave PTT key recording and Escape to cancel it without closing the containing panel.

**Architecture:** Keep key classification in a small voice leaf helper. The Vue component delegates recording keystrokes to the helper and applies its resulting state and assignment.

**Tech Stack:** Vue 3, TypeScript, Vitest.

---

### Task 1: Capture behavior

**Files:**
- Create: `frontend/src/voice/ptt_key_capture.ts`
- Create: `frontend/src/voice/ptt_key_capture.spec.ts`
- Modify: `frontend/src/voice/AudioSettings.vue`

- [x] Write focused tests for Escape cancellation, Tab navigation, and ordinary key assignment using event spies.
- [x] Run `npm test -- ptt_key_capture.spec.ts` from `frontend` and confirm a failing red test before implementation.
- [x] Implement `capturePttAssignment(event, onStop, onAssign)` so Escape stops propagation and cancels, Tab permits native navigation, and an ordinary key prevents default and assigns its code:

  ```ts
  if (event.key === 'Tab') {
    stopRecording()
    return
  }
  event.preventDefault()
  stopRecording()
  if (event.key === 'Escape') {
    event.stopPropagation()
    return
  }
  assign(event.code)
  ```

- [x] Replace the component's unconditional `preventDefault()` handler with this helper:

  ```ts
  function capturePttKey(event: KeyboardEvent): void {
    if (!recordingPttKey.value) return
    capturePttAssignment(event, () => { recordingPttKey.value = false }, (code) => emit('setPttKey', code))
  }
  ```

- [x] Run the focused test, full `npm test`, and `npm run build` from `frontend`.
- [x] Record browser-controller limitation and native validation in bounded DES-05 evidence; leave overall acceptance PARTIAL.
