# BOOHTACORD patches

This package is based on the `livekit_client` 2.13.0 release. Its upstream
license and source are retained.

The local change aligns the SDK's bounded reconnect delays and jitter with the
web client's `BoundedVoiceReconnectPolicy` in
`frontend/src/voice/bounded_voice_reconnect_policy.ts`. Keep the focused policy
test in `test/core/voice_reconnect_policy_test.dart` when rebasing a future
LiveKit SDK update.
