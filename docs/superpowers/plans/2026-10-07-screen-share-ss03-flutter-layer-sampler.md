# SS-03 Flutter per-layer sender sampler

## Route

Leaf: `clients/flutter/lib/src/features/screen/metrics`.

## Packet

Keep a bounded in-memory sender-layer sample per active screen session, keyed
by LiveKit stream ID and RID. Derive FPS, bytes, retransmitted packets, packet
loss and NACK/PLI/FIR rates from valid intervals. Select only a progressing
layer for the existing report and clear all baselines at stop. Retain the
server report allowlist and keep total track bitrate separate.

## Files

- `layers.dart` and focused Flutter sampler tests.
- `livekit_layers.dart` adapter for the pinned local LiveKit model.
- `metrics/controller.dart`, `metrics/sample.dart`, and `app/media_access/screen.dart`.

## Validation

Run focused Flutter tests and package/client analysis with the project's pinned
Flutter SDK. If the SDK is unavailable, record `NOT_RUN`; hardware and SFU
comparison remain separate acceptance evidence.

## Stop condition

This packet covers sender-layer intervals and exposes the local metrics to the
screen owner. Native capture/presentation provenance, receiver decode/freeze
intervals, SDK integration tests and device acceptance remain open in #159.
