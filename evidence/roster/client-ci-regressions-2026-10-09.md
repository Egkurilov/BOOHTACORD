# Roster client CI regressions

Route: `review_gate` → exact roster expiry and native composition edges.

- Original PR #285 CI failed two AppState tests. They waited for the old delayed
  error and used `Stream.value`, whose EOF immediately means disconnection.
- Move those scenarios to bounded `voice_roster_state/app_composition_test.dart`:
  stale is announced immediately, retained data expires after 100 ms, and only a
  replacement stream that stays open proves fresh recovery. Initial 503 recovery
  also uses an explicitly controlled stream. Existing unrelated tests remain.
- AppState/roster/setup/quality native matrix: **PASS**, 92 tests on Flutter
  3.47.5 / Dart 3.13.4; no skipped test in this focused command.
- Actual Web defect: manual reconnect changed generation while a stale timer
  still referenced the previous generation, retaining expired data indefinitely.
  New regression failed before the fix and passed afterwards.
- Expiry now survives stream replacement; new success, session expiry and stop
  cancel it. Retain the last successful timestamp for age, but expire the data.
  Connection banner distinguishes expired data from a retained stale snapshot.
- Web roster/banner matrix **PASS**, 14 tests; vue-tsc + Vite production build
  **PASS** with explicit isolated test origin. Initial build without required
  `VITE_PUBLIC_ORIGIN` failed configuration validation; corrected command passed.
- Physical/native production and the full CI rerun remain **NOT_RUN** here.

No capture, join, credentials, ACL or real user data is introduced by this fix.
