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
[QA-184](../../../../evidence/flutter/qa184-android-app-window-capture-resize-2026-10-01-001.json).

The related LiveKit encoding support and Flutter profile logic live in
`clients/flutter/packages/livekit_client` and `clients/flutter/lib/src/services/screen_share_quality.dart`.
See [QA-88](../../../../evidence/flutter/qa88-android-screen-share-resolution-cap-2026-09-29-001.json).

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
Physical Android receiver and OS-stop acceptance remain open; see [QA-26](../../../../evidence/flutter/qa26-android-media-projection-service-2026-09-27-001.json).
The capturer also emits low-frequency, content-free log events for projection
start, captured-content visibility changes, OS stop and normal app teardown to
support diagnosis of app-only blanking versus capture termination — [QA-208](../../../../evidence/flutter/qa208-android-projection-diagnostic-events-2026-10-02-001.json).

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
acceptance remain open; see [QA-98](../../../../evidence/flutter/qa98-windows-screen-capture-start-failure-2026-09-29-001.json)
and [QA-103](../../../../evidence/flutter/qa103-desktop-screen-share-rollback-2026-09-29-001.json).

## Windows audio input route failure reporting

The Windows `AudioDeviceModule::SetRecordingDevice` result is checked when
selecting an input. A failed native route change or device enumeration now
returns a generic MethodChannel error instead of reporting success and letting
Flutter persist a device that the ADM rejected. The device-selection result
mapping has a standalone C++ regression test. The Windows plugin CMake target
builds and runs it. Real Windows hardware capture acceptance remains open.

## Source and maintenance policy

[UPSTREAM.json](UPSTREAM.json) pins the published upstream archive SHA-256,
license and changed source files, measured against the verified pub.dev archive.
The local overrides remain required. Return to upstream only after the fixes
are included and the focused tests plus affected platform media acceptance pass.

Additional retained patches cover AGP built-in Kotlin compatibility, direct
Android frame buffers and capture serialization, EGL surface-release barriers,
and macOS renderer disposal/first-frame propagation. Their JVM/Dart tests are
listed in the upstream record. The macOS/Darwin texture renderer now emits its
first-frame event only after copying a pixel buffer and notifying Flutter that
the texture frame is available — [QA-206](../../../../evidence/flutter/qa206-macos-texture-first-frame-upload-2026-10-02-001.json). When an RTC video track changes, the renderer also releases a pending texture-frame gate left by the old track; otherwise an unsampled frame could block the new track. This lifecycle regression is covered by [QA-209](../../../../evidence/flutter/qa209-macos-renderer-track-replacement-2026-10-02-001.json). Compilation alone does not certify hardware.

Renderer texture, srcObject and first-frame work is generation-gated so late
native callbacks from an older publication cannot replace the selected viewer.
The Flutter viewer pauses its bounded five-second first-frame deadline while
the app/window is backgrounded, performs at most one automatic subscription
retry per generation, and starts that retry immediately for a matching
`TrackSubscriptionExceptionEvent`. If the retry does not produce a frame, the
viewer exposes an immediate explicit retry action. The subscription lifecycle
rebinds the selected LiveKit track through its normal renderer path.
Focused Flutter/device acceptance remains pending; no hardware behavior is
claimed.
