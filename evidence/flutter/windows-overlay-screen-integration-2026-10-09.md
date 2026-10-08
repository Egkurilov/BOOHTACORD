# Windows overlay and screen rollout integration review

## Bounded packet

- Integration baseline: `6d5f3be5a954d61a9ff6f83bfeb4ac579dd1d1ad`.
- Route: review_gate, Windows overlay account/native lifecycle and #176 screen preferences/rollout. The concrete account defect below was repaired as a separate small_direct leaf change.
- Source boundary: overlay `windows_bridge/configuration.dart`, account cleanup/initialization, media screen preferences and existing native overlay runtime leaves. No media engine, Room, microphone, capture or server behavior was introduced.
- Toolchain: Flutter 3.47.5 / Dart 3.13.4, MSVC 19.44.35229 / Windows SDK 10.0.26100.0, Windows 11 Pro 10.0.26300.

## Finding and preservation fix

The old cleanup removed callbacks but kept the bridge revision and typed settings. A new account could bind its callbacks before its asynchronous settings save/restore completed. A late placement event from the previous native revision was therefore accepted and saved old enabled/scale/monitor values to the new account. A late configuration completion also left the bridge's displayed configuration enabled after logout, even though the existing session guard correctly kept the feed disabled.

Two focused tests on the real AppState first failed with those old values. Cleanup now calls `OverlayConfigurationBridge.clearAccount()`: increments the callback/configuration revision, clears typed settings/editor state and callbacks. Disposal uses the same invalidation. Native placement and error callbacks from the old revision are rejected, and late configure completion cannot enable the feed. Stored settings of the old account are preserved. Native hidden snapshots still destroy the window and unregister the shortcut.

The merged initialization retains both overlay preparation and `restoreScreenPreferences()` before audio bootstrap. Screen restoration keeps its account/origin/session and idle-publication guard. There is no extra media acquisition during preference restoration.

## Observed checks

- Red regression: both real-AppState account boundary tests failed on the integration baseline; old placement saved enabled=true, scale=2 and old monitor to account B, and bridge state remained enabled after the closed account's native completion.
- `flutter test --no-pub test/voice_overlay test/features/screen_rollout --reporter expanded`: **PASS, 44 tests**.
- `flutter test --no-pub test/workspace_screen_test.dart test/features/voice/prejoin test/features/workspace/quick_jump test/voice_overlay test/features/screen_rollout --reporter expanded`: **PASS, 142 tests**.
- Scoped `flutter analyze --no-pub lib/src/features/voice/overlay/windows_bridge lib/src/app/account_lifecycle test/voice_overlay/session_boundary`: **PASS, no issues**.
- `python -m tools.verify.dependencies.dart`: **PASS, 1323 local Dart files**.
- Native standalone test target compiled the actual production overlay C++ with `/W4 /WX`: **PASS**. Actual OS HWND checks prove nonactivation/focus preservation, normal click-through, explicit editor hit tests and exit, configured opacity, missing-monitor work-area restore, disable/recreate/destroy, real hotkey registration conflict/retry/release and hidden state across newer roster snapshots. Production decoders are checked for malformed configuration/snapshot rejection.
- Fresh `flutter build windows --debug --no-pub`: **PASS, 155.4s**. Final fixed source with explicit conservative #176 flags `BOOHTACORD_SCREEN_DESCRIPTOR_V1=true`, `BOOHTACORD_SCREEN_PREVIEWS_V1=true`, `BOOHTACORD_SCREEN_BOUNDED_SIMULCAST=false`: **PASS, 27.3s**. Existing vendored RNNoise/SoLoud warnings are not new owned-source errors; the dedicated native overlay target is clean with warnings treated as errors.
- Changed production/test leaf files remain below the 120-line hard limit; new account-boundary test is 98 lines in its own one-test leaf.

## Acceptance boundary

Physical calls, screen streams, game compatibility/exclusive fullscreen, monitor unplug/cross-DPI movement, accessibility on hardware and paired performance measurements remain **NOT_RUN**. Unit tests, HWND witnesses and compilation do not establish media capacity, real multi-monitor behavior or game performance. No release artifact was published and no production mutation was performed.

Slavik Gym report: route=review_gate; packet=windows-overlay-screen-integration; tokens=estimated:7000; method=manual_estimate; driver=issues112+176; next_split=physical-QA.
