# Viewer Playback FPS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show measured viewer playback FPS, including a frozen stream, without inventing values when the browser has no frame API.

**Architecture:** A small observer counts `requestVideoFrameCallback` deliveries over two-second windows and reports `null` until a frame is seen. The viewer owns the observer lifetime per selected stream and passes the result to the existing quality formatter. Dimensions and FPS reset when selection ends or changes.

**Tech Stack:** Vue 3, TypeScript, Vitest, Vite.

---

### Task 1: Measured FPS observer

**Files:**
- Create: `frontend/src/voice/screen_playback_fps.ts`
- Test: `frontend/src/voice/screen_playback_fps.spec.ts`

- [x] Add tests for no initial frames (`null`), two frames in two seconds (1 FPS), a subsequent frozen window (0 FPS), missing browser API (`null`), and cleanup canceling the frame request and timer.
- [x] Run `npm test -- --run src/voice/screen_playback_fps.spec.ts`; confirmed missing-module failure before implementation.
- [x] Implement `observeScreenPlaybackFps(video, onSample)` using the browser frame callback, one two-second timer, and idempotent cleanup. `null` means unmeasured; 0 means observed playback became frozen.
- [x] Run the focused Vitest file; all tests pass.

### Task 2: Viewer formatting and lifetime

**Files:**
- Modify: `frontend/src/voice/screen_video_quality.ts`
- Create: `frontend/src/voice/screen_playback_quality.ts`
- Modify: `frontend/src/voice/ScreenViewer.vue`
- Test: `frontend/src/voice/screen_viewer_reference.spec.ts`

- [x] Keep the existing failing formatter assertions and add a viewer assertion that FPS observation starts for a selected stream and stops on selection change and unmount.
- [x] Run `npm test -- --run src/voice/screen_viewer_reference.spec.ts`; confirmed the formatter/wiring assertions fail before implementation.
- [x] Add an optional `number | null` FPS parameter to the formatter; render `FPS не определена` for null and `${fps} FPS у зрителя` for measured values, including 0.
- [x] Observe only the selected, active video; stop and reset on selection change, stream end, and unmount. Avoid showing stale dimensions before the new video's first decoded frame.
- [x] Focused tests pass. Full `npm test` (237 tests) and `npm run build` passed before concurrent FE-02 edits; final combined validation belongs to integration after FE-02 is complete.

### Self-review

- [x] Confirm no target/source FPS is presented as measured playback.
- [x] Confirm unsupported frame API remains no-data and a frozen observed stream becomes 0 FPS.
- [x] Confirm viewer callback and interval cannot outlive selection or component unmount.
