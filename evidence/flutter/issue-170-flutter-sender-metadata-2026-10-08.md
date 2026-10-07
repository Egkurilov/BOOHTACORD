# Issue #170 — Flutter sender metadata receiver

Date: 2026-10-08. Route: Flutter screen viewer diagnostics.

## Implementation

- Flutter reads `boohtacord.screen-share.v1` from the selected LiveKit remote
  participant's existing `attributes` map. No API or shared contract changed.
- The parser accepts bounded v1 JSON only, validates the exact descriptor,
  deployment origin, owner account/room, counters and requested profile/mode
  relation. Missing attributes remain compatible with older participants.
- Viewer diagnostics show sender mode and requested profile in separate rows.
  Receiver resolution/FPS remain sourced only from receiver statistics; no
  sender target is presented as actual quality.
- New focused tests cover v1 parsing, backward compatibility, invalid scope,
  malformed/oversized metadata and stale generation/revision/session updates.

## Checks

- **PASS** `python -m tools.verify.dependencies.dart` — 749 Dart files; import
  and feature/UI boundaries valid.
- **PASS** `git diff --check`.
- **NOT_RUN** `flutter test test/features/screen/sender_metadata` — Flutter SDK
  is unavailable on this host (`flutter` is not recognized); `dart` is also not
  installed. The new Dart tests therefore have not been executed here.
- **NOT_RUN** Flutter runtime verification on Android, Windows or macOS. Before
  acceptance, run focused tests and exercise a real sender/viewer pair; attach a
  redacted descriptor (IDs replaced consistently), device/OS/Flutter/LiveKit
  versions, selected mode/profile, actual receiver resolution and presented FPS,
  and mark each platform **PASS**, **FAIL** or **NOT_RUN**. Keep requested
  sender profile distinct from the measured receiver values.
