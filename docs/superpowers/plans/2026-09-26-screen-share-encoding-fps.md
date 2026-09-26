# Screen Share Encoder FPS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep the selected 30/60 FPS target through both browser capture and LiveKit screen video encoding.

**Architecture:** `startScreenShare` already sends `resolution.frameRate` to capture, but the pinned LiveKit JS 2.22.3 merges its 15 FPS screen encoding default into publication. Add per-profile `screenShareEncoding.maxFramerate` at the same call, reusing the pinned SDK's 720p30/1080p30 bitrate and medium priority values. Preserve voice-first degradation and adaptive receive behavior; actual decoded FPS still requires real observer measurements.

**Tech Stack:** Vue 3/TypeScript, LiveKit JS 2.22.3, Vitest.

---

### Task 1: Prove the capture-to-encoder mismatch

**Files:**
- Modify: `frontend/src/voice/livekit_screen_publishing.spec.ts`
- Read: `frontend/node_modules/livekit-client/src/room/defaults.ts`
- Read: `frontend/node_modules/livekit-client/src/room/participant/LocalParticipant.ts`

- [x] **Step 1: Write the failing test.** Iterate all four `ScreenProfile` values. For each, assert `setScreenShareEnabled(true, capture, publish)` receives the same target FPS in `capture.resolution.frameRate` and `publish.screenShareEncoding.maxFramerate`, with `maxBitrate` 2,000,000 at 720p or 5,000,000 at 1080p and `degradationPreference: 'maintain-framerate'`.
- [x] **Step 2: Run `npm --prefix frontend test -- --run src/voice/livekit_screen_publishing.spec.ts`.** Expect the new publish assertion to fail because `screenShareEncoding` is absent.

### Task 2: Pass the selected FPS to the encoder

**Files:**
- Modify: `frontend/src/voice/media_publishing.ts`
- Test: `frontend/src/voice/livekit_screen_publishing.spec.ts`

- [x] **Step 3: In `media_publishing.ts`, add `screenShareEncoding: { maxBitrate: number; maxFramerate: number; priority: 'medium' }` to `ScreenSharePublishOptions`.** Define the bitrate values as the pinned SDK's `ScreenSharePresets.h720fps30.encoding.maxBitrate` and `h1080fps30.encoding.maxBitrate` values, respectively; use the selected profile's `resolution.frameRate` as `maxFramerate`. Keep the existing `degradationPreference`.
- [x] **Step 4: Run `npm --prefix frontend test -- --run src/voice/livekit_screen_publishing.spec.ts`.** Expect all profile assertions to pass. Verify 30 FPS profiles are not silently forced to 60 and 60 FPS profiles are not capped at 15.

### Task 3: Validate and record limits

**Files:**
- Modify: `frontend/src/voice/screen_diagnostics.spec.ts`
- Modify: `frontend/src/voice/screen_diagnostics.ts`
- Create: `evidence/media/screen-share-encoder-fps-2026-09-26-001.json`

- [x] **Step 5: Write a failing diagnostics test with source `settings.frameRate: 60` and no sender FPS; expect measured dimensions but no `framesPerSecond`.** Then change `normalizeScreenDiagnostics` to use only positive sender FPS for this measured field. Preserve the dimensions fallback.
- [x] **Step 6: Run `npm --prefix frontend test -- --run src/voice/screen_diagnostics.spec.ts`, `npm --prefix frontend test`, and `npm --prefix frontend run build`.** Expect all to pass.
- [x] **Step 7: Record code-level cause, changed options, commands/results, and `NOT_RUN` for two-user moving-content media verification.** Do not claim actual 60 FPS until decoded FPS and sender stats are measured on the required hardware and network.
- [x] **Step 8: Inspect `git status --short`, changed file sizes, and `git diff --check`; hand files to the parent agent for integration.** The parent owns commit, push, deployment, and TODO/DONE updates.
