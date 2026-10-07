# Issue #177 — audio discovery lifecycle follow-up

Date: 2026-10-07
Source SHA: `0aa3faa5`
Scope: #177 and the lifecycle portions of #179, #180, #181, #182, #183.

## Implementation

- Removed the constructor-side fire-and-forget `Hardware.enumerateDevices()`.
  The application controller now owns the initial bootstrap → enumerate → apply
  path.
- Device-change callbacks are debounced and coalesced. A refresh updates the
  SDK's selected-device cache and falls back when a selected endpoint is gone.
- Audio discovery exposes `idle`, `initializing`, `ready` and `error` states,
  with separate permission, initialization and enumeration failure categories.
  UI errors no longer expose exception types or device identifiers.
- Concurrent bootstrap calls remain single-flight; account cancellation and
  late scans retain their existing scope guards.

## Automated evidence

- **PASS** 88 focused Flutter tests covering bootstrap ordering, single-flight,
  stale-scan cancellation, hot-plug replacement, selection/rollback, pre-join
  capture options, reconnect policy and AppState lifecycle.
- **PASS** `flutter_webrtc` factory bootstrap regression test.
- **PASS** Flutter application analyzer for changed files; full analyzer has
  only pre-existing info-level style findings.
- **PASS** local `flutter_webrtc` and `livekit_client` analyzers.
- **PASS** macOS Release build:
  `clients/flutter/build/macos/Build/Products/Release/BOOHTACORD.app` (98.9 MB).
- **PASS** Android Release build:
  `clients/flutter/build/app/outputs/flutter-apk/app-release.apk` (53.8 MB).

## Physical acceptance

- **PASS (prior evidence)** macOS Debug pre-join inventory and non-default
  selection/restore are recorded in
  `evidence/2026-10-07-issue-177-factory-bootstrap.md`.
- **NOT_RUN** USB/Bluetooth connect/disconnect while Audio Settings is open.
  The current validation host reports no CoreAudio endpoints through
  `system_profiler SPAudioDataType`, so a real hot-plug route cannot be
  observed here.
- **NOT_RUN** privacy-indicator denied/recovery flow and Release voice-route
  verification require a host with an available microphone and a second
  playback endpoint. These remain release-gate blockers for closing #177/#184.
