# Android background microphone implementation plan (#51)

Goal: preserve existing user-started microphone publishing while Android is
backgrounded, with a microphone foreground service independent from capture.
Route: small_direct; voice/background_microphone and native start-service leaf.
Do not touch mixed MainActivity or AppState. Native auto-registration comes from
a repository-owned Flutter plugin, using the existing Flutter Gradle loader.
Ratchet: target100/hard120 physical lines; leaf target8/hard16 files/tests.

Policy: ADR006 amendment; only explicit user microphone intent may begin SDK
capture. Check visible Activity before capture. Existing SDK permission/capture
flow grants RECORD_AUDIO; promote microphone FGS while still visible before
confirming that operation. If promotion fails, disable that microphone and keep
listener fallback. No extra capture, Room, lease, token or battery exemption.
Stop on mute/deafen/listener, leave/logout/dispose and terminal disconnect.
Do not stop independent mediaProjection when microphone service stops.

## Source and native checks

- [x] Baseline voice lifecycle/microphone/audio/Android screen readiness tests.
- [x] Write focused background_microphone/session_test.dart before session.dart:
  startup only on Android, failure denies, stop cancels pending generation,
  bounded service timeouts and native stopped callback preserve muted intent.
- [x] Add packages/boohtacord_voice_foreground native plugin manifest,
  pubspec/build.gradle, Kotlin start/{VoiceMicrophonePlugin,Visibility,
  MicrophoneService,Notification,AdmissionPolicy}. Microphone service is private,
  nonsticky and has no boot receiver, record/capture implementation or wake lock.
  Check current Activity visibility and RECORD_AUDIO before each fresh start;
  native acknowledgement occurs only after actual startForeground succeeds.
- [x] Add plugin dependency in clients/flutter/pubspec.yaml and resolve lock.
- [x] Bind VoiceController optional foreground session, capture preflight/promotion
  and fail-closed cleanup through <=120line child admission/control files.
  Add close/dispose edges without changing AppState or mediaProjection lifecycle.
- [x] Run focused Flutter tests and scoped analyze, native JVM admission policy
  tests, Android debug Kotlin compilation and merged manifest checks.
- [x] Attempt actual emulator only if available: ADB currently no devices and
  SDK emulator directory absent. Record unavailable emulator/physical paired
  voice transfer as NOT_RUN, never infer continuity from compilation.
- [x] Amend ADR006 and FE68, save evidence/flutter/android-background-microphone-
  2026-10-09.md, inspect status/sizes and local commit only. Root owns integration.

Official requirements reviewed2026-10-09:
https://developer.android.com/develop/background-work/services/fgs/service-types#microphone
https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start

Stop: source and available native checks complete with separate device QA gate.
