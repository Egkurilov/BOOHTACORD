# BOOHTACORD patches

This local fork is based on `flutter_webrtc 1.6.2+hotfix.3`. Keep these changes
when rebasing or restoring the package from pub.dev.

## Android MediaProjection track settings

`GetUserMediaImpl.getDisplayMedia` includes the actual display width, height,
and capture frame-rate in the created track's `settings` map. Android's native
screen capture does not apply the requested 16:9 `getDisplayMedia` constraints;
exposing the real source size lets LiveKit apply the user's selected
resolution cap to its outgoing RTP encoding without cropping portrait frames.

The related LiveKit encoding support and Flutter profile logic live in
`desktop/packages/livekit_client` and `desktop/lib/src/services/screen_share_quality.dart`.
See [QA-88](../../../evidence/flutter/qa88-android-screen-share-resolution-cap-2026-09-29-001.json).

## MediaProjection stop propagation

The Android capturer forwards the OS `MediaProjection.Callback.onStop` event to
the Dart track-ended dispatcher. The Dart dispatcher buffers an early native
event until LiveKit attaches its `onEnded` callback and delivers it at most
once. This allows a system-level stop to unpublish the local screen track.
Physical Android receiver and OS-stop acceptance remain open; see [QA-26](../../../evidence/flutter/qa26-android-media-projection-service-2026-09-27-001.json).
