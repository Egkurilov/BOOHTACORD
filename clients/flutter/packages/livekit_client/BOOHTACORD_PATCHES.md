# BOOHTACORD patches

This package is based on the `livekit_client` 2.13.0 release. Its upstream
license and source are retained.

The local change aligns the SDK's bounded reconnect delays and jitter with the
web client's `BoundedVoiceReconnectPolicy` in
`clients/web/src/voice/bounded_voice_reconnect_policy.ts`. Keep the focused policy
test in `test/core/voice_reconnect_policy_test.dart` when rebasing a future
LiveKit SDK update.

`VideoEncoding` also carries an optional `scaleResolutionDownBy` value through
`toRTCRtpEncoding()`. Android screen-share profiles use this to cap the longer
edge of a real MediaProjection source while preserving portrait/landscape
aspect ratio. Keep `test/utils_test.dart` coverage for the RTP parameter.
The application derives the even-pixel scale from the selected profile and
reported capture dimensions; see
`clients/flutter/lib/src/services/screen_share_quality.dart` and
[QA-88](../../../../evidence/flutter/qa88-android-screen-share-resolution-cap-2026-09-29-001.json).

## Source and maintenance policy

[UPSTREAM.json](UPSTREAM.json) pins the published upstream archive SHA-256,
license and changed source files, measured against the verified pub.dev archive.
The local overrides remain required. Return to upstream only after the fixes
are included and the focused tests plus affected platform media acceptance pass.

Additional retained patches cover AGP built-in Kotlin compatibility, local audio
RTT statistics, screen publication discovery before subscription, and bounded
video-renderer first-frame callbacks. The focused tests are listed by path in
the upstream record. `python -m tools.ci.native.flutter` runs the vendor suites.
