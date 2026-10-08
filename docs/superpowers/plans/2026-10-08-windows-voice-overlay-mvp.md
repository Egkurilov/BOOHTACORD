# Windows Voice Overlay MVP Implementation Plan

> **For agentic workers:** This implementation is already authorized; execute the steps inline and keep the PR limited to the first usable Windows overlay slice.

**Goal:** Show and hide a click-through Windows voice overlay from the existing connected BOOHTACORD session without creating another Flutter engine, LiveKit room, or microphone capture.

**Architecture:** The existing Flutter voice and roster controllers produce a bounded ID-free snapshot. A Windows-only method channel forwards snapshots to one sibling Win32 window owned by the current runner process; the existing voice dock toggles visibility. The window starts hidden, stays topmost without activation, passes pointer input to the game, and is destroyed with the runner.

**Tech Stack:** Flutter/Dart, Flutter Windows `MethodChannel`, C++17, Win32 layered popup window, Flutter unit/widget tests, Windows CI build.

---

### Task 1: Make the existing feed toggleable and test the lifecycle

**Files:**
- Modify: `clients/flutter/lib/src/features/voice/overlay/feed.dart`
- Modify: `clients/flutter/lib/src/features/voice/overlay/current_feed.dart`
- Modify: `clients/flutter/lib/src/app/composition/media.dart`
- Modify: `clients/flutter/lib/src/app/composition/owners.dart`
- Modify: `clients/flutter/lib/src/app/composition/dispose.dart`
- Test: `clients/flutter/test/voice_overlay/feed_test.dart`

- [ ] Add an `enabled` value owned by `AppOwners`, defaulting to false; refresh the snapshot when it changes.
- [ ] Preserve existing channel matching, 12-member cap, reconnect speaking reset, and ID-free output.
- [ ] On leave, logout, disconnect, and owner disposal, publish the hidden empty snapshot before stopping the feed.
- [ ] Add regression assertions for enable, disable, disconnect, reconnect, and disposal clearing.
- [ ] Run `flutter test --no-pub test/voice_overlay` from `clients/flutter`.

### Task 2: Add the Windows snapshot channel and click-through sibling window

**Files:**
- Create: `clients/flutter/lib/src/features/voice/overlay/windows_client.dart`
- Create: `clients/flutter/windows/runner/voice_overlay_window.h`
- Create: `clients/flutter/windows/runner/voice_overlay_window.cpp`
- Create: `clients/flutter/windows/runner/voice_overlay_paint.cpp`
- Create: `clients/flutter/windows/runner/voice_overlay_channel.h`
- Create: `clients/flutter/windows/runner/voice_overlay_channel.cpp`
- Modify: `clients/flutter/windows/runner/flutter_window.h`
- Modify: `clients/flutter/windows/runner/flutter_window.cpp`
- Modify: `clients/flutter/windows/runner/CMakeLists.txt`
- Test: `clients/flutter/test/voice_overlay/windows_client_test.dart`

- [ ] Encode only `visible`, display name (maximum 64 characters), speaking, and mute state in `boohtacord/voice_overlay/setSnapshot`.
- [ ] Keep the channel client unattached on non-Windows platforms; send the initial hidden snapshot and every later feed update on Windows.
- [ ] Create one independent topmost layered popup with `WS_EX_NOACTIVATE` and `WS_EX_TRANSPARENT`; render the capped member list and mute/speaking state in `voice_overlay_paint.cpp` using Win32 GDI.
- [ ] Place it at the upper-right of the monitor nearest the main window, clamp to that monitor's work area, and hide/destroy it on hidden snapshot or runner shutdown.
- [ ] Validate channel arguments and member count before rendering; malformed calls hide the panel and return an error.
- [ ] Unit-test method name, bounded snapshot serialization, hidden clearing, and non-Windows no-op behavior.
- [ ] Run the Windows Flutter runner CI build; no release APK or distribution build is part of this plan.

### Task 3: Add a voice-dock show/hide control and keep scope explicit

**Files:**
- Modify: `clients/flutter/lib/src/screens/workspace_screen.dart`
- Test: `clients/flutter/test/workspace_screen_test.dart`
- Modify: `docs/clients/windows-voice-overlay.md`

- [ ] Add an accessible Windows-only voice-dock button labelled “Показать панель говорящих” / “Скрыть панель говорящих”; default it off and disable it outside a connected/listener voice session.
- [ ] Toggle the current feed and native window without acquiring a track, microphone, permission, or LiveKit room.
- [ ] Test that the button changes state, is absent on other platforms, and becomes hidden when voice disconnects.
- [ ] Document the MVP's single-monitor/basic-DPI limits and leave hotkey, edit mode, saved preferences, multi-monitor restoration, accessibility review, game matrix, anti-cheat, and paired performance acceptance as explicit follow-up gates.
- [ ] Run `flutter test --no-pub test/voice_overlay test/workspace_screen_test.dart` and changed-file Dart analysis.

### Task 4: Review and hand off

**Files:**
- Review: all files listed in Tasks 1–3.

- [ ] Confirm the final diff contains no second engine, room, microphone/capture call, IDs, credentials, audio, DM text, or logging of roster data.
- [ ] Check `git status --short` and changed-file lengths before staging; keep production and direct-test counts within the route limits.
- [ ] Push the semantic branch and open a PR linked to #112; keep #112 open because real Windows/game acceptance and remaining settings/monitor gates are not source-verified.
