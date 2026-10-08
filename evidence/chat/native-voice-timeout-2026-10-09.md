# Native temporary voice timeout — #97

Date: 2026-10-09. Base: `37ced0a7936fdab62d0a9e4d2ff5113a09f13202`.
Route: split_first. Approved decision: ADR-023; native T-051/T-050 binding.
This packet contains scoped typed HTTP and an actual Flutter moderation dialog.
Existing admin compact/desktop launch-button wiring is owned by root integration.

## Source and behavior

- `features/admin/voice_timeout` owns immutable typed state/input, strict parser,
  existing secure-cookie/Origin transport and ApiClient facade. GET reads only
  `/accounts/{id}/voice-timeout`; PUT202/DELETE200 use administrator routes.
- Input is a future UTC expiry at most24h plus one of DISRUPTION, HARASSMENT,
  SPAM, OTHER. No free text or peer moderation state is added. Parsing rejects
  extra fields, invalid UTC date/active combination and negative/non-integer counts.
- `screens/admin_voice_timeout` owns the single dialog lifecycle, duration/reason
  fields, authoritative load, explicit apply/lift, confirmation/cancel, pending/error
  states and retry. Logical revocation count and pending SFU confirmation remain
  separate; no label claims physical media termination.
- Session ticket/deployment revision guard requests and controller completion.
  Target replacement disposes the previous controller. Root's scopeChanges notifier
  also immediately hides previously loaded moderation state on logout/server change.
- Dialog uses route SafeArea, focus acquisition and closed dialog traversal,
  480px maximum surface width, 16px margin and scrollable content. Actual compact
  widget verification uses320×640, reason/duration selection and keyboard focus.
- No VoiceJoin, microphone, screen transport, TEXT/DM or existing admin code changed.
  Expiry/manual lift requires the user's new explicit Join; it never restores leases.

## Root integration edge

Import `clients/flutter/lib/src/screens/admin_voice_timeout/dialog.dart`.
The existing ApiClient gains getVoiceTimeout/setVoiceTimeout/clearVoiceTimeout.
Initialize and launch using existing state/account objects:

```dart
await showAdminVoiceTimeout(context,
  api: state.api,
  accountId: member.id,
  displayName: member.displayName,
  scopeChanges: state);
```

No initialization fetch or side effect beyond opening the dialog is required.
Pure feature leaves import HTTP/facade contracts only; they do not import UI/AppState.

## Observed native acceptance

Environment: Windows, Flutter3.47.5, Dart3.13.4. All fixtures use synthetic IDs.

| Check | Result |
| --- | --- |
| Focused `flutter test --no-pub test/admin_voice_timeout` | PASS: 12 scenarios, 7 focused files |
| `flutter analyze --no-pub --no-fatal-infos` | PASS: no errors/warnings; 57 pre-existing info diagnostics, none in this packet |
| `flutter test --no-pub --concurrency=4 --reporter=json` | PASS: 937 tests, 1 pre-existing skip; success=true, 83.762s |
| Canonical `python -m tools.ci.native.contracts` | PASS: 260 tooling tests/1 existing skip; 19 contracts; 108 public/3 private endpoints; 1210 Dart boundaries; 468 document links |

The Flutter skip is `native Flutter SDK and frame observation survive real relay
and Tempo`, requiring the existing real relay/Tempo environment. Ignored `.out/`
retains native-voice-timeout-tests.jsonl, native-voice-timeout-analyze.log and
native-voice-timeout-contracts.log. All17 touched Dart files are at most99 actual
lines; source feature has3 files, UI leaf6 and direct test leaf7.

API/model and actual widget tests were red before the respective implementation.
Tests cover cookie+Origin, GET/PUT202/DELETE200, typed reasons/UTC<=24h, pending lift
state, read-before-mutate, session/origin/disposal stale completion, target replacement,
loaded-state hiding on logout, confirmations/cancel, member403/retry, compact geometry
and focus. Initial geometry check measured Dialog's outer alignment container rather
than its inset Material; the corrected assertion checks the actual visible surface.
Source extraction from dialog lifecycle into surface preserved focused acceptance.

## Remaining acceptance

Released device/production-equivalent SFU acceptance: NOT_RUN in this native packet.
No production mutation, release build, push/merge or issue mutation was performed.
No PostgreSQL session/tunnel was acquired by native work.
Root must bind administrator launch buttons and run combined integration acceptance.
QA must exercise shipped clients against actual timeout state: all reasons/durations,
pending removal, clear/expiry with a new explicit Join only, denied peer reads, revoked
credentials/token replay, server/account changes and uninterrupted TEXT/DM.
