# Viewer presented FPS metadata implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Measure the viewer's compositor-submitted frames when `requestVideoFrameCallback` skips callbacks, without claiming that this proves a 60 FPS LiveKit stream.

**Architecture:** Keep the observer in the existing `screen_playback_fps` leaf. Use `VideoFrameCallbackMetadata.presentedFrames` deltas within the timed window; retain callback-count fallback for browsers or tests without a finite counter. Do not change sender/receiver transport stats or the POC-02 acceptance rule.

**Tech Stack:** Vue 3/TypeScript, Vitest 5, browser `HTMLVideoElement.requestVideoFrameCallback`.

---

### Task 1: Detect missed callback frames

**Files:**
- Modify: `frontend/src/voice/screen_playback_fps.spec.ts`
- Modify: `frontend/src/voice/screen_playback_fps.ts`

- [x] **Step 1: Write the failing test.** Extend `videoFrames()` with `emitFrame(presentedFrames?: number)` and pass `{ presentedFrames } as VideoFrameCallbackMetadata`. Add:

```ts
it('counts compositor frames missed between callbacks', () => {
  vi.useFakeTimers()
  const frames = videoFrames()
  const samples: Array<number | null> = []
  const stop = observeScreenPlaybackFps(frames.video, (fps) => samples.push(fps))
  frames.emitFrame(11)
  frames.emitFrame(15)
  vi.advanceTimersByTime(2000)
  expect(samples).toEqual([2.5])
  stop()
})
```

- [x] **Step 2: Confirm red.** Run `npm --prefix frontend test -- --run src/voice/screen_playback_fps.spec.ts`; expect the new case to return `1` instead of `2.5`.
- [x] **Step 3: Implement the counter delta.** Preserve the current no-data/frozen behavior and count `presentedFrames - previousPresentedFrames` when both are finite and increasing; count one frame at the first callback, on absent metadata, or after a counter reset.
- [x] **Step 4: Confirm green.** Run the focused spec, `npm --prefix frontend test -- --run`, and `npm --prefix frontend run build`; require all PASS.

### Task 2: Record evidence without overstating POC-02

**Files:**
- Create: `evidence/media/qa07-viewer-presented-counter-2026-09-26-001.json`
- Modify: `backlog/VERIFICATION_TODO.md`
- Modify: `TODO.md`
- Modify: `templates/poc-02-evidence.json`
- Modify: `docs/POC_02_OPERATOR_RUNBOOK.md`

- [x] **Step 1: Record the pre-fix failure, final tests/build, and that two-client sender/receiver measurements remain NOT_RUN.**
- [x] **Step 2: Link the source fix from QA-07 and run `scripts/verify-spec-traceability.ps1`.**
- [x] **Step 3: Inspect candidate files, sizes, and `git diff --check`; commit only exact files.**
