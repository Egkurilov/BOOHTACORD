# Windows overlay settings and automated native acceptance — #112

Scope: remaining source preferences/editor/hotkey/display recovery after MVP and only-speakers mode. Uses the preserved workspace conversion, the existing Flutter engine, one existing authorized LiveKit Room and one sibling system window. No game hooks, new microphone, camera, media owner or DM payloads.

## Delivered source

- Real Windows dock menu opens account-local enabled, scale, opacity, participant cap, placement preset, F-key and modifier settings. The old only-speakers preference remains under its existing key; new settings use an account-local v2 JSON key. Defaults remain opt-in off. Late account operations are rejected.
- Explicit editor permits pointer dragging without activation. End-of-drag persists normalized work-area position and monitor choice. Normal mode passes pointer input to the game. Hiding/disconnect closes native edit mode; shutdown detaches callbacks.
- Native layout uses current DPI and scale, searches saved monitor names, falls back to the main-window monitor, clamps to its work area, and updates on display/DPI messages. Dragging between different DPI monitors accepts the OS suggested geometry.
- Native RegisterHotKey uses MOD_NOREPEAT, reports registration failure/conflict, supports retry, and releases the key during disconnect/disable/teardown. Hotkey-hidden state is preserved across speaker updates; it does not activate the window.
- Disconnect/disable destroys the native window; a later valid snapshot recreates one window. Disabled feeds remove voice/roster observer subscriptions; re-enable does not duplicate them. Newest-snapshot coalescing cancels queued stale visible states after disable/disposal.
- The current authorized Room supplies actual membership and microphone state, so departed participants cannot remain from a stale roster and names still work before SSE arrives. Matching roster names remain display hints. Speaking reads existing LiveKit events; reconnect clears speaking through the existing projection. Avatar initials require no image or credential transport.

## Native ownership and preservation

Flutter runtime is physically in roster_display, preferences_store, settings and windows_bridge leaves; UI is in screens/voice_overlay_controls and screens/voice_overlay_settings. Old feature entrypoints only forward exports. Native lifecycle, bridge, painting, placement/events, configuration and typed decoders are separate child leaves, explicitly rewired through CMake. No executable part-file substitution or validator exception.

57 owned source/test files checked at closeout: maximum 114 lines, zero over-hard. Overlay direct Dart files: 15 (hard limit16); largest immediate production leaf has 6 files. Existing 79 workspace tests remain; old feed assertions remain, with three fixtures explicitly enabled before source notifications because disabled overlays now intentionally release subscriptions. The enable/disable scenario moved unchanged to a separate bounded test file.

## Observed verification

Environment: Windows11 Pro10.0.26300, Flutter3.47.5, Dart3.13.4, Visual Studio2022 BuildTools/MSBuild17.14.60.

- Focused new model API red: FAIL before implementation (missing model).
- Disabled-listener regression red: FAIL (one subscription remained while disabled), then PASS.
- Snapshot-boundary regression red: FAIL (queued visible snapshot returned), then PASS.
- Room membership fallback red: FAIL before helper; final current-Room tests PASS.
- Full native overlay Flutter group: PASS30.
- Combined workspace + prejoin + quick jump + overlay: PASS128; 79+6+13+30, no skipped tests.
- Scoped Flutter analyzer: PASS, no issues.
- python -m tools.verify.dependencies.dart: PASS, source edges and feature/UI boundaries.
- Owned source sizes and git diff check: PASS.
- Standalone native runtime test executable compiled /W4 /WX /utf-8 and ran: PASS. It checks real OS overlay window visibility, no foreground change, non-activation, hit testing, explicit editor, opacity, missing-monitor fallback/work-area bounds, teardown/recreation, actual OS hotkey conflict/retry/release, visibility across live snapshots, and strict numeric/snapshot decoders.
- flutter build windows --debug --no-pub: PASS, final29.2 seconds. Initial numeric decoder C4456 failed /WX; distinct integer variable names fixed it. Existing vendored RNNoise/SoLoud warnings are separate from the clean native test target. Debug executable is generated/ignored, not staged.

Native reproduction from clients/flutter: configure windows/runner/voice_overlay/runtime_tests with CMake/Visual Studio17 2022 into an ignored build directory; build Debug and run voice_overlay_native_checks.exe. The target consumes the exact production native implementations and Flutter's existing ephemeral C++ headers.

## Physical QA remaining

NOT_RUN: paired users speaking simultaneously in a real call, real games/windowed/borderless/anti-cheat/exclusive-fullscreen, physical monitor unplug/plug and cross-monitor DPI, minimized client/Alt+Tab during gameplay, hardware screen-reader behavior, and paired FPS/frame-time/CPU/GPU/RAM measurement. The OS fixture does not prove game compatibility or hardware budgets. Record SHA/binary, OS/GPU/game, display/DPI arrangement, steps and sanitized outcomes. Never attach member IDs, credentials, DM bodies or audio.

Slavik Gym report: route=voice/overlay child leaves + screen settings + Win32 sibling window; packet=small_direct with physical source boundary correction; tokens=estimated:26000; method=manual_estimate; driver=issue112 remaining source and unattended native emulation; next_split=physical game/performance QA.
