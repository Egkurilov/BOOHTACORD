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
