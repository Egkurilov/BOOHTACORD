# #106 — physical voice shortcuts and lifecycle completion

Date: 2026-10-05. Mode: implementation, code-only owner delivery.
Base: origin/master 3623a9f53e18b5a3798827150eb7db9e5729cfc9.
Initial implementation 6aa94ee4 was already in master; this is a follow-up.

## Operating brief / preservation

Classification split_first, structure_no_rg. Leaf routes T-022 (T-006/T-020)
with T-050/T-051 UI bindings. Search boundary: voice shortcut model/capture,
preferences and exact workspace/media import edges plus direct tests.
Doctrine: existing microphone/deafen operations own media state; preserve ACL,
account scope and touch PTT. No shortcut/input telemetry, no API contract change.
Ratchets target100/hard120 and leaf target8/hard16 production/direct-test files.
Model/capture/runtime/settings ownership moved physically into shortcut child
leaves; old public imports forward. Existing oversized workspace/session files
receive only exact bindings; workspace shortcut logic/row were extracted.
Stop: merge code [skip ci]; acceptance remains open until grouped run.

## Implemented delta (source inspection, not executed acceptance)

- Physical key capture and typed parsing; old native logical preferences readable.
- Reserved/search/PTT/duplicate validation on assignment and preference restore.
- Focus, visibility, repeat, editable/IME/modal guards and pending-command gating.
- Session/room/command ownership suppresses stale completion; account teardown
  clears bindings/status. Focus loss invalidates announcements, not media cleanup.
- Existing voice guards prevent shortcut mic enabling in listener/PTT/reconnect/
  unavailable/deafened; deafen delegates to existing controller.
- Local account persistence, explicit reset, failed-save handling.
- Visible accessible live status outside audio settings; responsive native rows.
- Native mobile hardware-key discovery preserves touch PTT. Exact disconnect
  detection without lifecycle transition is an acknowledged device acceptance item.

## Authored checks, all NOT_RUN

Owner: “пока не собирай новые сборки … потом прогоним скоупом”. No native tests,
analysis/typecheck, e2e, builds, CI or deployment were run for this packet.
Dart source formatting and manual diff/size/status inspection only.

| Check | Result | Deferred command / scenario |
| --- | --- | --- |
| Web focused Vitest | NOT_RUN | npm test -- src/voice/shortcuts src/voice/voice_shortcut.spec.ts src/voice/voice_shortcuts.spec.ts src/voice/microphone_controls.spec.ts |
| Web type analysis | NOT_RUN | npx vue-tsc --noEmit |
| Real Vue capture/runtime fixture | NOT_RUN | npx playwright test -c tests/voice_shortcuts/playwright.config.ts |
| Native focused model/prefs/widget/runtime | NOT_RUN | flutter test test/voice_shortcut_test.dart test/voice_shortcut_capture_test.dart test/voice_shortcut_preferences_test.dart test/voice_shortcut_lifecycle_test.dart test/voice_shortcut_widgets_test.dart test/audio_preferences_test.dart |
| Native analysis | NOT_RUN | flutter analyze |
| Windows device | NOT_RUN | layout switch, foreground/blur/repeat, pending toggle/account switch, real mute/deafen output restore |
| Android/iOS device | NOT_RUN | no keyboard hidden, hardware key reveals, keyboard removal/background, touch PTT/input/IME regression |
| Server-backed Web voice e2e | NOT_RUN | real capture permissions/listener/reconnect, muted/deafened output and account isolation |
| Build/release/deploy | NOT_RUN | owner deferred grouped release |

The browser fixture mounts production capture/status/runtime/execution components
with controlled voice actions; it does not prove LiveKit or device media behavior.
Existing media controllers and fixture/device acceptance must also be run.
Issue #106 must not be marked fully accepted from this code-only record.
