# Flutter workspace conversion and roster UI — 2026-10-09

Scope: #270 Flutter prejoin recovery UI; physical decomposition of the existing workspace screen before connecting the retry action. Based on 0402e2be; prior roster-controller and screen-capability commits are separate dependencies.

## Source and native ownership

The original 9,290-line widget library is a one-line forwarding export. Its actual implementation is physically owned by child widget, event-handler, lifecycle, render and derived-feedback libraries under `clients/flutter/lib/src/screens/workspace_ui`. `native_bindings.dart` and component facades only export native dependencies. No `part` library or static reference application replaces the runtime.

`features/voice/prejoin` owns the real card, member row and roster preview. The preview preserves cached participants with a historical label after loss, reports unavailable separately from known fresh empty rooms, offers bounded-controller manual retry, and requests login after session expiration. The real header uses the same phase semantics. Join/listen buttons remain explicit user actions.

All 330 extracted production Dart files are <=120 lines; immediate leaf maximum 5 production files. Names identify UI responsibilities (history, composer, member summary, room viewer, overlays, keyboard/window lifecycle). The final derived layout/search-feedback leaves preserve existing breakpoint and status decisions. No aggregate contains a second runtime implementation.

## First-pass preservation

The 79 existing workspace widget scenarios remain. They cover TEXT/DM drafts, reply/send/retry, visible history anchors and read cursors, message editing conflicts, navigation/drawers, keyboard focus, source selection, participant volume, screen views and miniplayer, window/voice callbacks, profile/admin access and Design V2 geometry.

Listener callbacks remain typed State/mixin methods so add/remove observe the same function identity. Super lifecycle calls remain at their original points. Render extraction moves existing constructor subtrees without inserting new widget wrappers. Nullable promotions lost at library boundaries are expressed as the same existing nonnull preconditions, without changing normal action availability.

Three baseline text/fixture expectations were updated for the requested roster phases: bounded failure copy, a disconnected SSE's historical roster label, and an explicitly fresh phase for a manually injected synthetic fresh snapshot. Production passthrough setters are unchanged. Unknown actions and media ownership were preserved.

## Observed verification

Flutter 3.47.5/Dart 3.13.4.

- Initial preservation baseline 79 workspace tests: PASS.
- Mid-conversion 79 workspace tests: PASS.
- Header regression tests before correction: FAIL 2/3; stale empty looked current and expired looked loading.
- Final `flutter test --no-pub test/workspace_screen_test.dart test/features/voice/prejoin --reporter expanded`: PASS 85, including all 79 original scenarios plus 6 focused UI/header tests.
- `flutter analyze --no-pub lib/src/screens/workspace_screen.dart lib/src/screens/workspace_ui lib/src/features/voice/prejoin test/features/voice/prejoin`: PASS, no issues, 15 seconds.
- Scoped native `dart analyze --format machine` on the owned UI/prejoin and focused tests: PASS, no diagnostics.
- Native formatter and owned-file size review: PASS; no owned production file exceeds 120 lines.

Hardware capture, paired-device calls and authenticated production roster acceptance: NOT_RUN by this packet. These results prove source/component behavior, not physical media performance.
