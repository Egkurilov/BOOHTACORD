# Windows voice overlay — implementation investigation

Status: implementation proposal; native runtime work awaits owner approval of
the rendering boundary. Issue: [#112](https://github.com/Egkurilov/BOOHTACORD/issues/112).

## Existing component map

| Responsibility | Current owner | Overlay reuse |
| --- | --- | --- |
| Windows message loop and main window | `clients/flutter/windows/runner/main.cpp` | Keep the existing process and message loop. |
| Flutter window and DPI changes | `clients/flutter/windows/runner/flutter_window.cpp`, `win32_window.cpp` | Add a sibling native window; do not start a second Flutter engine. |
| One authenticated LiveKit room | `clients/flutter/lib/src/features/voice/lifecycle/state.dart` | Read the current `VoiceController.room` only. |
| Active speakers and participant lifecycle | `clients/flutter/lib/src/features/voice/room_events/remote_participants.dart`, `refresh_voice_navigation.dart` | Reuse LiveKit events and the existing notifier. |
| Server roster | `clients/flutter/lib/src/features/voice/roster_state/` | Not a speaking source: its DTO has name, mute, and screen-share fields only. |
| Overlay-safe display projection | `clients/flutter/lib/src/features/voice/overlay/projection.dart` | Drops participant IDs, rejects stale channels, clears stale speaker flags, filters and caps members. |

## Proposed first-version boundary

Keep a single Flutter engine and the current authenticated LiveKit `Room`. A
small top-level Win32 window in the existing runner paints only projected
display names, mute state, and active-speaker state. Flutter sends snapshots
over a runner-owned method channel when the current `VoiceController` changes;
the overlay must never join LiveKit, acquire a microphone, or receive audio,
DM contents, session credentials, or account IDs. Clear its snapshot before
logout, voice leave/channel transfer, disconnect, and runner shutdown.

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

The pure projection tests cover channel isolation, reconnect speaker reset,
simultaneous speakers, only-speakers mode, maximum roster size, disabled state,
and clearing after disconnect. The Flutter application now derives a
snapshot-only feed from its existing `VoiceController` and current-channel
roster; the feed adds no LiveKit room, microphone capture, or participant IDs.
The feed is not yet connected to a native window, so it does not render an
in-game overlay. The feed and roster-projection tests were added, but are
`NOT_RUN` in the current environment because Flutter/Dart are unavailable.
The remaining integration needs a method-channel/native-window implementation
and Windows runner tests for pass-through, focus, hotkey conflict, DPI/monitor
restore, and deterministic destruction.
Manual acceptance must record Windows build, game and anti-cheat, display mode,
monitor/DPI topology, steps, expected/actual focus and input, and paired
60-second FPS/frame-time, CPU, GPU, and memory measurements with the overlay on
and off. No physical Windows/game acceptance is claimed by this investigation.

## Owner decision

Please confirm the proposed native Win32-painted sibling window, with one
Flutter engine and snapshot-only state transfer. This avoids duplicating
LiveKit/session logic and keeps game input pass-through at the OS window level.
Before merging the native runtime slice, also approve or replace the proposed
initial compatibility boundary (windowed and borderless-windowed only); hardware
performance budgets must be set from a paired baseline on the target Windows
machine rather than guessed from unit tests.
