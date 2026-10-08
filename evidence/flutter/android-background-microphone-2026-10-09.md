# Android user-started background microphone (#51 / FE-68)

Date: 2026-10-09 (Europe/Moscow). Source branch:
`codex/android-background-microphone`, based on `e57bf917`.
Development checks: PASS. Physical/emulator transfer: NOT_RUN.

## Source and preservation

ADR-006 now permits an independent private microphone foreground service, using
the existing user-intent SDK microphone and server lease/cookie/ACL paths.
Repository-owned Flutter plugin registration was verified in actual generated
`GeneratedPluginRegistrant.java`; MainActivity and AppState were not edited.
Native acknowledgement requires actual `startForeground` success, granted
RECORD_AUDIO and a visible Activity for a fresh start. An already active service
may continue while backgrounded; failure preserves muted listener intent.
No new Room, capture, wake lock, boot start or battery exemption is introduced.
The existing MediaProjection service remains independent.

Mute/deafen/listener stop through the existing microphone path; leave/logout,
terminal disconnect and dispose stop through controller cleanup. Unexpected
native service loss mutes and shows listener state without automatic restart.
Native and Dart timeouts bound unavailable service acknowledgement and stop.
SDK `AudioCaptureOptions` default stopAudioCaptureOnMute is preserved through
VoiceCaptureOptions, so SDK disable stops the microphone capture.

## Tests and actual build evidence

- Baseline: 23 existing lifecycle, microphone/audio and Android screen tests PASS.
- Initial focused tests failed before missing session/native implementation.
- Leave-during-SDK-permission regression initially failed: actual SDK calls were
  `[true]`, expected `[true,false]`. The old cancellation branch returned before
  disabling a late SDK microphone; corrected without starting another capture.
- Stronger denial tests initially failed twice because internal microphone intent
  remained false. Native preflight/promotion failure now preserves muted intent
  and listener state; controller cases PASS.
- Final full `flutter test --no-pub --reporter compact`: 873 PASS, one existing
  skip, zero failures, exit 0 (60 seconds). Includes nine focused session/controller
  cases, native manifest contract and existing MediaProjection/lifecycle tests.
- Scoped `flutter analyze --no-pub` for owned voice files/tests: PASS, no issues.
- `flutter build apk --debug --config-only --no-pub`: PASS; configuration only,
  no APK rebuild/distribution produced for this verification.
- Actual Gradle `:boohtacord_voice_foreground:testDebugUnitTest
  :app:processDebugMainManifest --console=plain`: PASS, 56 tasks (15 seconds).
  Kotlin production code compiled; five JUnit admission tests, zero skipped,
  failures or errors. First compile exposed Java17/Kotlin21 mismatch; plugin JVM
  target corrected to 17, then native compilation passed.
- Actual merged app manifest contains FOREGROUND_SERVICE_MICROPHONE and private
  MicrophoneService with `microphone`; IsolateHolderService remains
  `mediaProjection`. Generated Flutter registration binds VoiceMicrophonePlugin.
- Spec traceability: PASS, 39 approved requirements and brief SHA-256.
- `git diff --check`: PASS. Owned native source max68 lines; touched Dart source
  remains below hard120; new production leaves have five/two implementation files.

Local ignored logs: `.out/android-microphone-flutter-tests-final.log` and native
JUnit XML under Flutter build/test-results. Generated registrants, SDK config,
Gradle outputs and logs are excluded from the source commit.

## Remaining runtime acceptance

ADB devices inventory: no devices. Installed SDK has platforms34/35/36 but no
emulator runtime directory. Therefore emulator and physical runs are NOT_RUN.
No media continuity claim follows from compilation or source tests.

Run Android14+ and physical Pixel with an independent voice peer: start from
visible Activity, separately muted/unmuted background and resume, with/without
screen sharing; correlate server roster and publication, growing sender encoded
and peer decoded counters and audible transfer. Test permission denial, attempt
fresh background unmute, notification/service termination, mute/deafen, leave,
logout and process restart; verify no autojoin/unmute/capture and independent
MediaProjection cleanup. FE-68 retains only this QA gate.

Official requirements reviewed2026-10-09:
[microphone FGS](https://developer.android.com/develop/background-work/services/fgs/service-types#microphone),
[while-in-use start restrictions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start).
