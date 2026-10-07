# ScreenShare SS-04 Web Publisher Implementation Plan

Implementation status: source and automated test work complete. Live SFU,
device, and cross-client acceptance remain `NOT_RUN`.

> **For agentic workers:** This packet is executing inline under the parent task's explicit delegation. The steps use checkbox syntax to preserve the review trail.

**Goal:** Route Web screen-share start, update, and stop through one revision-bound adapter while preserving the capture and independent audio tracks.

**Architecture:** Initial capture goes through LiveKit's public `setScreenShareEnabled` with explicit VP8, two-layer simulcast options matching the pinned SDK's current screen-share topology. A live quality update applies capture constraints to the existing `LocalVideoTrack`, then uses public `unpublishTrack(track, false)` and `publishTrack(track, options)` calls; this replaces publication metadata and sender through the SDK while keeping capture, screen audio, and microphone alive. Operations bind to the active session object, room, and publication generation; stop invalidates pending work and late publication success is cleaned up. No app mutex is described as synchronizing SDK sender writes.

**Tech Stack:** Vue 3, TypeScript, LiveKit Client 2.22.3, Vitest.

---

## Route and source map

- Leaf route: `clients/web/src/voice/screen_publisher`.
- Existing UI/session entry: `clients/web/src/voice/voice_screen_session.ts`.
- Existing Web facade and API contract: `clients/web/src/voice/media_publishing.ts`, `clients/web/src/voice/livekit_gateway.ts`.
- SDK composition edge: `clients/web/src/voice/livekit_room_factory.ts`.
- Existing profile guard: `clients/web/src/voice/screen_profile/{bind,guard,apply}.ts`.
- Nearest tests: `clients/web/src/voice/livekit_screen_publishing.spec.ts`, `clients/web/src/voice/screen_profile/{publishing,apply,guard_races}.spec.ts`.
- Native checks: `npm test -- --run <focused specs>` and `npx vue-tsc --noEmit` from `clients/web`.

## SDK writer inventory

- App start currently calls `LocalParticipant.setScreenShareEnabled(true, ...)`; stop calls the same public API with `false`.
- App live-update currently mutates capture via `MediaStreamTrack.applyConstraints`, then writes `RTCRtpSender.setParameters` from `screen_profile/apply.ts`.
- Pinned SDK `LocalVideoTrack` owns sender parameter writes for publish, dynacast, and backup codec; `LocalParticipant` owns track publish/unpublish/reconnect. `RTCRtpSender.setParameters` stays exclusively behind SDK methods.
- Pinned public republish methods accept `LocalVideoTrack` and `TrackPublishOptions`; `unpublishTrack(track, false)` stops monitoring but does not stop the underlying capture. The screen-audio track remains separately published.
- The #157 profile catalog now documents source-derived runtime topology: Web and Flutter non-Android preserve up to two SDK primary layers with the low layer capped at 15 fps; Flutter Android uses one primary layer. Catalog entries are marked `source-derived-unvalidated`, and backup-codec/SFU topology remains unvalidated.

## Task 1: Define and test the explicit publication plan

**Files:**
- Create: `clients/web/src/voice/screen_publisher/plan.ts`
- Test: `clients/web/src/voice/screen_publisher/plan.spec.ts`
- Modify: `clients/web/src/voice/media_publishing.ts`

- [x] Add the focused assertions before implementation:

```ts
expect(screenPublishPlan('P1080_60')).toMatchObject({ videoCodec: 'vp8', simulcast: true,
  screenShareSimulcastLayers: [{ encoding: { maxFramerate: 15 } }],
  degradationPreference: 'maintain-framerate', screenShareEncoding: { maxBitrate: 8_000_000, maxFramerate: 60 } });
expect(screenCapturePlan('P1080_60').contentHint).toBe('motion');
expect(screenCapturePlan('P1080_30').contentHint).toBe('text');
```

- [x] Run the focused publication-plan test before implementation.
- [x] Implement `screenPublishPlan(profile)` from the profile catalog with explicit `name`, VP8 codec, `simulcast: true`, one half-resolution 15 FPS layer, selected original bitrate/FPS, and mode-based degradation preference; implement `screenCapturePlan(profile)` with target dimensions and `contentHint` (`motion` at 60 FPS, otherwise `text`).
- [x] Rerun the focused test and require PASS.

## Task 2: Add revision-bound publisher adapter tests

**Files:**
- Create: `clients/web/src/voice/screen_publisher/adapter.ts`
- Test: `clients/web/src/voice/screen_publisher/adapter.spec.ts`
- Modify: `clients/web/src/voice/screen_profile/{apply,guard}.ts` and nearest tests.

- [x] First test these behaviors with an injected port: start publishes once with the full plan; update reuses the same capture and preserves screen audio/microphone; A→B→C applies only the last queued intent; stop invalidates a blocked capture update; a publication that resolves after stop is immediately unpublished and its capture stopped; rollback restores the prior capture constraints and publication plan when a new publish fails.
- [x] Run the focused adapter tests before implementation.
- [x] Implement an adapter with a monotonically increasing operation revision, serialized start/update queue, immediate stop invalidation, an active-session identity check, a room/publication-generation check, and explicit partial-failure results. Keep stop idempotent and clean stale success through SDK port methods.
- [x] Change `screen_profile/apply.ts` into capture-only constraint application; remove every app-owned `sender.getParameters()`/`sender.setParameters()` write. Ensure diagnostic inspection cannot invoke reconfiguration; retain inactive/adapted/drift statuses and current-binding checks.
- [x] Run adapter, profile apply, and guard race specs; require PASS before integrating the composition edge.

## Task 3: Wire the adapter to the pinned public SDK API

**Files:**
- Modify: `clients/web/src/voice/{livekit_gateway,livekit_room_factory,media_publishing,voice_screen_session}.ts`
- Test: `clients/web/src/voice/{livekit_screen_publishing,screen_profile/publishing}.spec.ts`

- [x] Extend the structural room API with the adapter port and a publication generation that increments on screen-video published/unpublished events.
- [x] Wire the LiveKit port to `setScreenShareEnabled`, `getTrackPublication(Track.Source.ScreenShare)`, `unpublishTrack(videoTrack, false)`, `publishTrack(videoTrack, plan)`, and `unpublishTrack(..., true)` for cleanup. Do not read private fields or cast to `any`.
- [x] Route UI start/update/stop through the adapter. Adopt the initial profile after its single publish, and explicitly stop profile diagnostics on stop, logout, disconnect, OS stop, and revoked session.
- [x] Preserve the screen-audio publication on live video profile updates. On actual stop or stale late-success cleanup, remove both screen-share publications and stop held capture tracks; never touch microphone publication.
- [x] Run the focused SDK wiring tests, full Web Vitest suite, and `npx vue-tsc --noEmit`.

## Acceptance limits

- Unit tests can prove operation ordering, last-intent, cleanup, and that the screen-audio/microphone ports are not called during a video-only update.
- Real LiveKit SFU behavior, metadata as observed by a second client, OS picker cancellation, audio continuity, reconnect/dynacast races, and physical FPS/audio require the isolated #158 baseline environment and device evidence. Keep these `NOT_RUN` if that environment is unavailable; do not close #160 based on mocks.
- Keep SFU/device runtime and cross-client acceptance `NOT_RUN` until the isolated
  environment and hardware evidence are available; the GitHub issue stays open.
