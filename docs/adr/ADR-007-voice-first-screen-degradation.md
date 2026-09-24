# ADR-007: voice-first network adaptation for screen sharing

- Status: Accepted
- Date: 2026-09-24
- Decision owner: Project engineering

## Context

REQ-SCREEN-01 requires voice and connection continuity to take priority over screen image quality under constrained bandwidth. It allows image resolution, frame rate and bitrate to fall, and calls for cautious return to the requested quality. The requested capture profile remains a user target, not a promise that the browser or encoder can achieve it.

The pinned `livekit-client` 2.22.3 exposes `AudioPreset.priority`, screen-track `degradationPreference`, and Room options for `adaptiveStream` and `dynacast`. The SDK documents `maintain-framerate` as preferring frame rate while allowing resolution to decrease under bandwidth constraints; its screen-share default instead prefers resolution. Actual platform and server behavior remains unproven until media evidence exists.

## Decision

- Publish the mono Opus microphone with its existing 128,000 bit/s upper cap and `priority: high`.
- Publish screen video with `degradationPreference: maintain-framerate`, allowing the browser's WebRTC congestion controller to reduce resolution before frame rate where supported.
- Enable LiveKit `adaptiveStream` and `dynacast`; keep explicit `autoSubscribe: false` and the current one-selected-stream subscriber behavior.
- Keep the user's selected capture resolution/FPS as a target. Do not invent a screen bitrate ceiling, lower the selected target silently, add a stream-count quota, or route media through Go.

## Consequences

The implementation expresses voice-first network preferences and lets native WebRTC/LiveKit react to available bandwidth. It does not guarantee a particular measured resolution/FPS, smooth recovery, voice quality under overload, per-viewer isolation, or capacity. Adaptive receive behavior depends on the pinned LiveKit server/browser capabilities and available encodings. Windows and Apple Silicon macOS POC, stream-switch/recovery measurements, and 20-per-channel/100-per-deployment load evidence remain open.

## Verification

Unit tests prove only that the application passes these preferences to the SDK. Browser integration and the owner-run hardware/network tests are required before marking REQ-SCREEN-01, REQ-CAPACITY-02, or the release gate proven.
