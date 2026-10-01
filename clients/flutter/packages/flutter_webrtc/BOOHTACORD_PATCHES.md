# BOOHTACORD patches

This local fork is based on `flutter_webrtc 1.6.2+hotfix.3`. Keep these changes
when rebasing or restoring the package from pub.dev.

## Android MediaProjection track settings

`GetUserMediaImpl.getDisplayMedia` includes the actual display width, height,
and capture frame-rate in the created track's `settings` map. Android's native
screen capture does not apply the requested 16:9 `getDisplayMedia` constraints;
exposing the real source size lets LiveKit apply the user's selected
resolution cap to its outgoing RTP encoding without cropping portrait frames.

On Android 14+, `OrientationAwareScreenCapturer` also honors
`MediaProjection.Callback.onCapturedContentResize`. App-only capture can have
dimensions and aspect ratio different from the physical display; those content
dimensions now resize the virtual display and are not rotated to match the
device panel. Legacy/full-display capture keeps the existing orientation
normalization until MediaProjection reports authoritative content dimensions.
Unit coverage is recorded in
[QA-184](../../../evidence/flutter/qa184-android-app-window-capture-resize-2026-10-01-001.json).

The related LiveKit encoding support and Flutter profile logic live in
`desktop/packages/livekit_client` and `desktop/lib/src/services/screen_share_quality.dart`.
See [QA-88](../../../evidence/flutter/qa88-android-screen-share-resolution-cap-2026-09-29-001.json).

## macOS ScreenCaptureKit screen profile

The macOS 13+ full-display capture path reads the requested width/height
profile, caps ScreenCaptureKit's output by its longer edge, and rounds both
output edges down to even pixels. It preserves the selected display's aspect
ratio instead of forcing a 16:9 buffer. The custom window-source and macOS 12
fallback paths use the frame processor described below; physical runtime
acceptance remains open.

## macOS legacy and window screen profile

`FlutterScreenShareResolutionProcessor` applies the selected maximum long edge
to each captured frame before it enters the WebRTC video source. It preserves
frame aspect ratio, rounds output edges down to even pixels, and leaves frames
already within the profile untouched. This covers custom window capture and
the pre-macOS-13 screen fallback; physical source/profile acceptance remains
open.

## Android encoder dimension changes

The Android stream encoder wrapper now compares both input frame dimensions
with the encoder's configured dimensions before passing a frame through. A
height-only change (for example, during a portrait/landscape resize with a
stable width) is adapted to the full configured frame instead of being encoded
at a stale height. JVM tests cover matching dimensions and independent width
and height changes; real-peer crop acceptance remains open.

## MediaProjection stop propagation

The Android capturer forwards the OS `MediaProjection.Callback.onStop` event to
the Dart track-ended dispatcher. The Dart dispatcher buffers an early native
event until LiveKit attaches its `onEnded` callback and delivers it at most
once. This allows a system-level stop to unpublish the local screen track.
Physical Android receiver and OS-stop acceptance remain open; see [QA-26](../../../evidence/flutter/qa26-android-media-projection-service-2026-09-27-001.json).

## Desktop source thumbnail race

The native desktop capturer can emit a source preview while the asynchronous
`getSources` method response is still pending. Preserve that preview when
merging the response snapshot so callers can use its JPEG dimensions before
publishing. The ordering regression is covered by
`test/desktop_capturer_thumbnail_test.dart`.

## Desktop screen-capture start failure

`FlutterScreenCapture::GetDisplayMedia` checks the native capturer's start
state. When it returns `CS_FAILED`, the plugin removes the unpublished video
track/stream and any loopback-audio track, stops loopback capture, and rejects
the method call so Flutter cannot publish a healthy-looking but permanently
black track. The same rollback now covers stale/missing sources and video
capturer/source/track creation failures after this request started loopback
audio; it does not stop an unrelated active capture. Flutter displays the
native error message rather than the `PlatformException` wrapper. Windows
compilation passes, while injected-failure runtime and window-source
acceptance remain open; see [QA-98](../../../evidence/flutter/qa98-windows-screen-capture-start-failure-2026-09-29-001.json)
and [QA-103](../../../evidence/flutter/qa103-desktop-screen-share-rollback-2026-09-29-001.json).
