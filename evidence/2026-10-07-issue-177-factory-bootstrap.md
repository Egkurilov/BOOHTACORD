# Issue #177 — macOS audio factory bootstrap

Date: 2026-10-07
Source issue: https://github.com/Egkurilov/BOOHTACORD/issues/177

## Checks

- **PASS** `clients/flutter/packages/flutter_webrtc/test/unit/factory_bootstrap_test.dart`
  verifies `initialize → createPeerConnection → event cancel → peerConnectionDispose`,
  and confirms the idempotent second call does not create another connection.
- **PASS** Flutter `test/audio_devices/scan_scope_test.dart` and `test/app_state_test.dart`
  (61 AppState tests).
- **PASS** Flutter analyzer for the changed application files.
- **PASS** `flutter analyze --no-pub` in the local `flutter_webrtc` fork.
- **PASS** macOS debug build: `build/macos/Build/Products/Debug/BOOHTACORD.app`.
- **PASS** Android release build: `build/app/outputs/flutter-apk/app-release.apk` (53.8 MB).

## Physical acceptance

- **NOT_RUN** A physical macOS run with multiple USB/Bluetooth endpoints, privacy
  indicator observation, and hot-plug verification is still required. The local
  unit and build checks do not replace that evidence.
