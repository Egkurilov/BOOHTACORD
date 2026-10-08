# Windows voice overlay — implementation investigation

Status: first source MVP implemented on the #112 branch; Windows/game runtime
acceptance remains open. Issue: [#112](https://github.com/Egkurilov/BOOHTACORD/issues/112).

## Existing component map

| Responsibility | Current owner | Overlay reuse |
| --- | --- | --- |
| Windows message loop and main window | `clients/flutter/windows/runner/main.cpp` | Keep the existing process and message loop. |
| Flutter window and DPI changes | `clients/flutter/windows/runner/flutter_window.cpp`, `win32_window.cpp` | Add a sibling native window; do not start a second Flutter engine. |
| One authenticated LiveKit room | `clients/flutter/lib/src/features/voice/lifecycle/state.dart` | Read the current `VoiceController.room` only. |
| Active speakers and participant lifecycle | `clients/flutter/lib/src/features/voice/room_events/remote_participants.dart`, `refresh_voice_navigation.dart` | Reuse LiveKit events and the existing notifier. |
| Server roster | `clients/flutter/lib/src/features/voice/roster_state/` | Not a speaking source: its DTO has name, mute, and screen-share fields only. |
| Overlay-safe display projection and live feed | `clients/flutter/lib/src/features/voice/overlay/` | Drops participant IDs, rejects stale channels, clears stale speaker flags, filters and caps members; derives snapshots from existing controllers. |
| Windows snapshot transport | `clients/flutter/lib/src/features/voice/overlay/windows_client.dart`, `clients/flutter/windows/runner/voice_overlay_channel.cpp` | Sends only visibility, display name, speaking and mute state; no Room or microphone APIs. |
| Native overlay window | `clients/flutter/windows/runner/voice_overlay_window.cpp`, `voice_overlay_paint.cpp` | One sibling layered Win32 window, click-through and non-activating, destroyed with the existing runner. |
| User show/hide control | `clients/flutter/lib/src/features/voice/overlay/toggle.dart`, voice dock | Opt-in toggle appears only on Windows while connected; disconnect sends an empty hidden snapshot. |

## Proposed first-version boundary

Keep a single Flutter engine and the current authenticated LiveKit `Room`. A
top-level Win32 window in the existing runner paints only projected display
names, mute state, and active-speaker state. Flutter sends snapshots over a
runner-owned method channel when the current `VoiceController` or roster
changes; the overlay never joins LiveKit, acquires a microphone, or receives
audio, DM contents, session credentials, or account IDs. A Windows-only voice
dock toggle enables/disables it. Disconnect and runner shutdown clear it.

Use a topmost layered window with `WS_EX_NOACTIVATE` and `WS_EX_TRANSPARENT` in
normal mode so input continues to the game. Disable pass-through only while the
existing overlay editor mode is open. Keep the overlay outside Flutter's quit
window ownership so minimizing the main window does not hide the overlay; the
existing process owns and destroys both windows. Register the optional hotkey
with `RegisterHotKey`; report registration conflicts and leave the preference
disabled until the user selects a different key.

Persist preferences locally under an account-scoped key. Recompute window
placement in physical pixels from per-monitor DPI and clamp its rectangle to
the selected monitor work area after display changes. Restore from the nearest
connected monitor when the previous display disappears. Do not inject into game
processes or install graphics hooks. Initial support is windowed and
borderless-windowed games; exclusive-fullscreen and anti-cheat compatibility
remain explicitly unclaimed pending game-matrix evidence.

## Verification boundary

Pure projection tests cover channel isolation, reconnect speaker reset,
simultaneous speakers, only-speakers mode, roster cap, disabled state, and
clearing after disconnect. Feed, show/hide, snapshot serialization, and native
window contract tests are present. Local execution is `NOT_RUN` because Flutter
and Dart are unavailable in the current environment; Windows CI must compile the
runner before source acceptance. No physical Windows/game acceptance is
claimed.

The initial renderer choice is a sibling Win32 window in the existing runner;
the issue requires a separate transparent overlay and forbids a second media
connection. This keeps one engine and makes click-through/non-activation an OS
window property. The MVP defaults hidden and exposes an in-client toggle.
Manual acceptance must record Windows build, game and anti-cheat, display mode,
monitor/DPI topology, steps, expected/actual focus and input, and paired
60-second FPS/frame-time, CPU/GPU/RAM measurements with the overlay on and off.
The MVP only claims a bounded initial desktop position on the monitor nearest
the main window. Hotkey registration, move/edit mode, saved account settings,
only-speakers control, robust multi-monitor/DPI restore, broader accessibility,
exclusive fullscreen, anti-cheat, and performance/game-matrix evidence remain
open follow-up gates.

## Compatibility boundary

The implementation supports an ordinary topmost window. The initial product
claim is limited to windowed and borderless-windowed games after manual tests.
Exclusive-fullscreen and anti-cheat compatibility remain unclaimed. Set
performance budgets from paired measurements on the target Windows machine;
do not infer them from unit tests or compilation.
