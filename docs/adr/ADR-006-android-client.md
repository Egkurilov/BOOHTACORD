# ADR-006: Android native client

- Status: Accepted
- Date: 2026-09-21
- Decision owner: Product owner

## Context

The repository already contains a Flutter client and a documented mobile backend integration contract, but the original release scope excluded a native mobile application. The product owner has explicitly requested an installable Android APK.

## Decision

Android client is an approved native client. It is built from the existing Flutter source under `desktop/` so authentication, topology, chat and voice behavior stay aligned with the desktop application.

The Android client:

- uses the existing HTTPS `/api/v1` contract and sends the deployment Origin expected by the backend;
- stores the opaque secure session cookie in Android encrypted storage and does not introduce bearer tokens or mobile OAuth;
- uses existing Voice lease and short-lived LiveKit credential flows;
- remains one-guild and does not add camera, recording, group DM, federation or a custom SFU;
- receives the same server-side ACL enforcement as every other client.

An APK proves that the source builds for Android. Voice/media capability and capacity claims still require physical-device evidence under `evidence/`.

## Consequences

The Flutter application now includes an Android runner and can produce release APK artifacts. Android-specific permissions are limited to internet access, microphone access and the foreground media behavior required by the existing voice feature. iOS and push notifications remain outside the approved scope.

## Amendment: user-started microphone continuity (2026-10-09, #51)

The approved Android voice feature may maintain an already enabled microphone
while the Activity is backgrounded. A private, nonsticky `microphone` foreground
service is independent from the existing `mediaProjection` service. Declare
`FOREGROUND_SERVICE_MICROPHONE` and `RECORD_AUDIO`; do not combine service types.

Before fresh microphone enablement, require the visible Activity. The existing
LiveKit/WebRTC capture path requests the microphone permission and starts capture.
Before confirming the operation, the native plugin rechecks visibility and granted
permission, then acknowledges only successful `startForeground`. A running
microphone service may continue through background/reconnect. A fresh background
start is denied. Failure disables the SDK microphone and preserves muted listener
intent; it must not create a second Room, lease or capture implementation.

Mute, deafen, listener mode, leave, logout, terminal disconnect and disposal stop
the microphone service. Unexpected native termination changes the UI to muted
listener and never automatically re-enables capture. A service is not restored
after task removal or process restart. Stop has no effect on MediaProjection.
No boot receiver, battery exemption, wake lock, camera or recording is added.

This follows [Android microphone service requirements](https://developer.android.com/develop/background-work/services/fgs/service-types#microphone)
and [while-in-use start restrictions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start),
reviewed 2026-10-09. Native compilation and lifecycle tests prove source behavior;
paired physical muted/unmuted background transfer remains an independent evidence
gate, including peer audio counters and cleanup after stop/logout. See
[implementation evidence](../../evidence/flutter/android-background-microphone-2026-10-09.md).
