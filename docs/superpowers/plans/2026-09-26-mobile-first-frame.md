# Mobile first-frame readiness Implementation Plan

> **For agentic workers:** Inline execution in the current task; the user already requested completion. Steps use checkbox syntax for tracking.

**Goal:** Remove the viewer's waiting overlay when a video frame is presented even if mobile Safari omits `loadeddata`.

**Architecture:** Keep the existing FPS sampler as the source of presented-frame events. Notify the playback-quality composable on its first frame; preserve `loadeddata` as a fallback and keep no-frame playback unknown.

**Tech Stack:** Vue 3, TypeScript, Vitest.

---

### Task 1: First-frame signal

**Files:** `frontend/src/voice/screen_playback_fps.spec.ts`, `frontend/src/voice/screen_playback_fps.ts`, `frontend/src/voice/screen_playback_quality.ts`.

- [x] Add a failing Vitest case: `observeScreenPlaybackFps(video, onSample, onFirstFrame)` invokes `onFirstFrame` once after the first browser callback, not before or after `stop()`.
- [x] Run `npm --prefix frontend test -- screen_playback_fps.spec.ts`; the new case failed as expected.
- [x] Add the optional first-frame callback to `observeScreenPlaybackFps` and set `videoReady` from that callback in `useScreenPlaybackQuality`. Preserve callback cancellation and stream-switch reset.
- [x] Run the focused test and `npm --prefix frontend run build`; both passed, as did the full 604-test suite.

### Task 2: Evidence and closeout

**Files:** `evidence/media/android-iphone-first-frame-2026-09-26-001.json`.

- [x] Record the two user-observed directions separately, the source-level fix, and the missing iPhone receiver counters without claiming a physical-device PASS.
- [x] Inspect `git status --short` and changed file sizes before staging; commit only reviewed files.

Self-review: this plan addresses viewer readiness only. It does not assume that the Android publisher sends frames; iPhone receiver counters and a repeat device run decide that separately.
