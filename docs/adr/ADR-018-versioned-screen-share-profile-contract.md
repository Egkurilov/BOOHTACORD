# ADR-018: Versioned screen-share profile contract

- Status: Accepted
- Date: 2026-10-07
- Decision owner: Project engineering

## Context

Web and Flutter have parallel profile tables and separate capture/encoding behavior. A requested profile is user intent; capture constraints and RTP layer parameters are effective configuration; presented frames and network stats are observations. These must not be represented as one measured quality value. The current production association between FPS loss and profile-table differences is unproven.

## Decision

- `contracts/screen-share-profile-v1.schema.json` defines the typed session descriptor. `contracts/screen-share-profile-v1.catalog.json` preserves existing profile IDs and bit/s values and records unvalidated experiment candidates. Shared fixtures are consumed by Web and Flutter tests.
- Descriptor identity is scoped by origin, account, room, logical media session, publication generation, and operation revision. Stop, revoke, and logout supersede pending work; stale completion cannot publish a track. Reconnect advances publication generation while preserving the logical share session when the current capture remains valid.
- Publisher/viewer state and reason codes are bounded enums. Requested profile, effective capture/encode plan, capability, and observed quality remain separate; observations carry their own provenance and are not added to this descriptor as a claim of success.
- Geometry uses one aspect-preserving scale, does not upscale, and produces even encoded dimensions when both source edges are at least two pixels. The legacy `P{resolution}_{fps}` IDs and their current bitrate values remain valid.
- One video publication is selected by each viewer. Single-layer is the baseline; simulcast is a bounded, explicit experiment with no more than two layers. LiveKit/WebRTC retain ownership of fast congestion adaptation. The application does not force minimum bitrate or periodic keyframes.
- Candidate targets (motion 720p60 at 3–4 Mbit/s, motion 1080p60 at 6–8 Mbit/s, and text 1080p15–30 at 2.5–5 Mbit/s) are unvalidated experiments. 1440p60 is research-only pending paired measurements. None is a capacity or device-support claim.

## Acceptance method

The proposed quality gates are p05 presented FPS of at least 55 for moving 60-FPS content, p95 first-frame/profile-switch latency at most 2 seconds, and no unexplained freeze over 500 ms. Before a gate is treated as accepted, the baseline task must specify duration, warm-up, sample windows, denominator, static/background exclusions, repeat count, and noise bounds. Capture settings, `maxFramerate`, and local preview do not prove presented throughput. Degraded-network recovery is evaluated separately with voice continuity taking priority.

## Compatibility and ownership

Existing profile IDs and publication names remain readable during rollout. Profile descriptor changes are independently disableable and unknown versions fall back without downgrade loops. Capture, sender, publication metadata, subscription, and renderer each have one writer; implementation-specific adapters are handled in SS-04/SS-05. Native video-only remains distinct from system-audio capture. This ADR does not claim that runtime, physical devices, SFU behavior, or proposed SLOs have passed acceptance.

| Resource | Owner | Boundary |
|---|---|---|
| Capture | Platform capture driver | Creates/releases source tracks and applies capture constraints. |
| Sender encodings | LiveKit publisher adapter | Applies a supported publish plan; SDK owns congestion adaptation. |
| Publication descriptor | Publisher adapter | Publishes requested/effective profile and revision for the active generation. |
| Remote subscription | Selected-stream viewer adapter | Keeps one selected video subscription per viewer. |
| Rendering | LiveKit renderer | Displays the selected subscribed track and reports only available observations. |

Scoped IDs are for operation correlation and ACL checks. They are not metric labels; diagnostic exports must use bounded reason codes and aggregates.
