# Voice-First Screen Degradation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use inline execution task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Configure LiveKit/WebRTC so voice keeps high media priority while screen video adapts its resolution before its frame rate under bandwidth pressure, without introducing a fixed stream quota or claiming unmeasured quality.

**Architecture:** Keep capture selection and requested dimensions in the existing screen-publishing leaf. Pass explicit publish preferences separately from capture constraints: high priority for the Opus microphone and `maintain-framerate` degradation preference for screen video. Enable LiveKit adaptive stream and dynacast at room construction so subscribed video can follow visible demand and unused video layers can be paused; actual platform behavior and smooth recovery remain measurement gates.

**Tech Stack:** Vue 3, TypeScript, `livekit-client` 2.22.3, Vitest.

---

## File map

- `frontend/src/voice/media_publishing.ts` owns microphone and screen capture/publish options.
- `frontend/src/voice/livekit_gateway.ts` defines the narrow room boundary and exports the media-publishing API.
- `frontend/src/voice/livekit_room_factory.ts` creates the single LiveKit room and will opt into adaptive stream/dynacast.
- `frontend/src/voice/livekit_gateway.spec.ts` is the nearest typed test for the publishing contract and will verify the exact arguments passed to the SDK boundary.
- `docs/adr/ADR-007-voice-first-screen-degradation.md` records the implementation choice and its unverified platform limits.
- `TODO.md` updates only the T-031 implementation status; network/media/load evidence remains open.

## Task 1: Lock the publishing behavior with tests

- [x] **Step 1: Add failing tests** in `frontend/src/voice/livekit_gateway.spec.ts` proving (a) microphone publishing requests `AudioPreset.priority: 'high'`, (b) screen capture settings preserve the selected target, and (c) screen publication receives `{ degradationPreference: 'maintain-framerate' }` separately from capture options.
- [x] **Step 2: Run the focused Vitest file** with `npm test -- --run src/voice/livekit_gateway.spec.ts` from `frontend/`; confirmed four expected failures before implementation.

## Task 2: Apply voice-first publishing options

- [x] **Step 1: Add narrow option types and immutable preferences** to `frontend/src/voice/media_publishing.ts`; retained microphone cap `128_000`, `forceStereo: false`, all four existing screen profiles, and picker behavior. Added only high-priority audio and screen `maintain-framerate` publish preference; no screen bitrate ceiling was invented.
- [x] **Step 2: Extend the `VoiceRoom.localParticipant.setScreenShareEnabled` boundary** in `frontend/src/voice/livekit_gateway.ts` with the SDK's optional third publish-options argument and pass it through `startScreenShare`.
- [x] **Step 3: Enable `adaptiveStream` and `dynacast`** in the single `Room` construction in `frontend/src/voice/livekit_room_factory.ts`; retained `autoSubscribe: false` and explicit one-stream viewer subscription behavior.
- [x] **Step 4: Run focused tests and the TypeScript/Vite build**; confirmed capture options, publish options, and existing stop behavior remain distinct.

## Task 3: Record decision and remaining evidence

- [x] **Step 1: Add ADR-007** describing the preference for voice over screen video, the WebRTC resolution-before-frame-rate tradeoff, adaptive-stream/dynacast scope, absence of invented bitrate/stream caps, and limits of unit tests.
- [x] **Step 2: Update T-031 and T-032 in `TODO.md`** to record this configuration and reconcile already-implemented stream volume/participant UI while leaving smooth recovery, real integration, Windows/macOS behavior, the 20/100 profile, and capacity unverified.
- [x] **Step 3: Review the diff** for accidental changes to capture permissions, screen audio, room authorization, or media transport; none were changed.
- [x] **Step 4: Run frontend tests/build plus contract and spec-traceability verifiers**; no physical POC or load claim was closed by this packet.

## Coverage and gaps

This packet implements the code-side voice-first network policy for REQ-SCREEN-01 and the adaptive receiver/resource configuration relevant to REQ-SCREEN-03 and REQ-CAPACITY-02. It does not establish game-audio capture, gradual recovery quality, publisher counts, p95 targets, Windows/macOS support, or the 100-participant capacity gate; those require the owner-run physical POC and later network/load evidence.
