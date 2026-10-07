# ScreenShare SS-05 Flutter Publisher Implementation Plan

Implementation status: source and focused test coverage are in place. Local
Flutter execution, SFU behavior, and device acceptance remain `NOT_RUN`.

## Route

- Leaf: `clients/flutter/lib/src/features/screen/{profile,lifecycle,quality}`.
- SDK ownership boundary: `clients/flutter/packages/livekit_client` local fork.
- Existing lifecycle entry remains `ScreenShareController`; capture remains
  owned by the native driver.
- Preserve Android's current single-layer profile pending device acceptance.

## Implementation

- [x] Keep latest quality intent only and drain it against the active account,
  room, track, ticket, and lifecycle revision.
- [x] Make screen profile encoding explicit and aspect-preserving; preserve
  even geometry and the current Android layer topology.
- [x] Replace direct feature-level sender writes with the pinned SDK's
  `updateScreenShareTrackProfile` public method.
- [x] Serialize LiveKit sender parameter writes by sender across dynacast,
  degradation, and the screen quality writer; retire writes while replacing a
  publication, drain in-flight writes, and reopen the new sender generation.
- [x] Republish the same capture through the local SDK publisher runner so new
  publication metadata and encoding state agree. Restore the prior profile on
  failure or return an explicit cleanup-required failure.
- [x] Preserve SessionTicket cancellation and late-capture cleanup; extract the
  publication helper from `start.dart` to keep the lifecycle leaf small.
- [x] Add lifecycle fixture, sender-lock, retirement-barrier, profile geometry,
  and quality rollback/supersede test cases.
- [x] Update the vendored SDK patch and upstream manifest without removing
  existing platform fixes or license headers.

## Verification limits

- Flutter/Dart SDK is not installed on the local runner, so Flutter analyzer,
  app tests, vendor tests, and native builds are `NOT_RUN` locally.
- PR CI is the next executable validation for Flutter and Windows.
- LiveKit/SFU republish, Android single-layer behavior, physical FPS, audio
  continuity, and stop/foreground-service cleanup require device evidence and
  remain `NOT_RUN`; issue #161 must remain open until those gates pass.
