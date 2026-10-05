# Critical five issues and Android distribution implementation plan

**Goal:** Implement #63, #71, #100, #101, #102 and reduce the signed APK download size.
**Architecture:** Keep one guild, existing session ACL/media revocation, exact-payload
message idempotency and server-authored system messages. Vue/Flutter consume existing
guild contracts; new session/message lookup endpoints remain caller scoped.
**Stack:** Go/PostgreSQL, Vue/Pinia, Flutter, Gradle and native Python delivery tools.
**Execution:** Inline, one bounded leaf packet at a time; no delegated agents.

## Operating brief

Route: split_first; size=large; structure/search=structure_no_rg.
Ratchets: file target100/hard120, leaf production/direct tests target8/hard16.
Primary checkout has unrelated work and is preserved. Reuse the attached release
worktree on codex/critical-five-and-apk-size, based on dcef7fe4/master.
Search exact selected capabilities and import edges; never search a broad aggregate.
Stop when all five implementations, focused/full native checks and measured APK
comparison are reviewable; never mark unavailable hardware/production checks PASS.

## Packet 1 — APK size (T-051, dependency T-050)

Files: tools/build/android/run.py and new apk_size/{inspect.py,test_inspect.py};
clients/flutter/android/app/build.gradle.kts; exact Android packaging contract tests.

- [ ] Measure actual android-v1.0.32 arm64 APK ZIP entries and SHA-256 first.
- [ ] Red test a packaging inspector against mixed ABIs, debug assets and raw native
  libraries; then implement deterministic counts and bounded size checks.
  Assertion: `assert report['native_compressed_bytes'] < report['native_bytes']`.
- [ ] Configure Gradle native library compression using its supported DSL. Keep
  APK ABI splits, application ID, signer, codecs, media and platform support.
- [ ] Build release before/after with pinned toolchain; compare actual bytes and
  entry hashes, verify native loading/16 KB compatibility on available Android.
  Commands: `python -m pytest tools/build/android/apk_size -q`;
  `python -m tools.build.android.run`; record download/install tradeoff explicitly.

## Packet 2 — caller-owned sessions, #63 (T-010/T-006)

Files: new backend/internal/identity/list_own_sessions and revoke_own_sessions
leaves; exact auth route composition/migrations/contracts; matching Web/Flutter
account-settings capabilities. Follow logout/authenticate/session revocation edges.

- [ ] Baseline existing logout, cookie authentication, WS invalidation and lease
  revocation. Add red repository/API tests for caller isolation and current session.
  Assertion: foreign public session ID returns NOT_FOUND and never revokes a lease.
- [ ] Add public random session handle/label/activity metadata with no digest, token,
  IP or fingerprint in DTO. Revoke selected/others atomically for the caller only.
- [ ] Bind CSRF/Origin and existing durable session/voice invalidation; add account
  settings UI with explicit current-session marker, busy/error/empty states.
- [ ] Run nearest Go integration, Web and Flutter tests plus contract validator.
  Check two clients, old cookie/WS/SDK credentials and initiating session survival.

## Packet 3 — delivery uncertainty, #71 (T-040/T-041; IMP-07)

Files: clients/web/src/conversation exact send/retry/store edges; Flutter
features/text/send_state and direct-message equivalents; corresponding message
DTO/row leaves and caller-authorized lookup repository/API/contracts if missing.

- [ ] Red test a committed message with lost HTTP response. Lookup by exact
  client_message_id must reconcile before retry; assertion: one stored server row.
- [ ] Implement sending/checking/failed states and conversation-local pending list.
  Preserve UUID for identical retry; changed payload gets a new UUID.
- [ ] Explicit 400/403 do not trigger blind retry; 507 keeps upload failure distinct.
  Removing an optimistic row invokes no server delete; account switch clears scope.
- [ ] Run focused Web/Flutter/Go checks and actual two-client browser acceptance.

## Packet 4 — guild settings, #100 (T-014/T-050/T-051)

Files: new Web guild/profile and guild/update_settings leaves; Flutter
features/guild/profile and features/admin/guild_settings; exact workspace/auth/
navigation/admin/realtime bindings. Preserve backend/internal/guild/update_settings.

- [ ] Red tests for public loading/fallback/title, revision ordering, stale account
  result, admin save/conflict/error and Unicode name boundaries.
- [ ] Implement profile fetch + revision-aware event refetch, live navigation/auth
  title, administrator editor and accessible long-name truncation.
- [ ] Run existing Go ACL/concurrency tests and new Web/Flutter tests; capture actual
  components at 1024/1440 px and 150% zoom plus native compact/desktop layouts.

## Packet 5 — system welcome, #101 (T-040; depends #100)

Files: exact Web conversation/message DTO/row leaves and admin guild settings;
Flutter text message DTO/row leaves and admin guild settings; existing Go
registration_welcome, register_user and chat semantics tests.

- [ ] Red tests require SYSTEM_WELCOME kind, current author name by stable ID,
  disabled user edit/reply/attachment, permitted admin delete and neutral notification.
- [ ] Add distinct system row and active-TEXT selector with disabled/empty/conflict
  states. Preserve registration/message atomicity and existing audit/realtime ACL.
- [ ] Verify enabled/disabled/unavailable/rollback/duplicate registration outcomes,
  real two-client appearance and reconnect dedup; run native contract checks.

## Packet 6 — private lifecycle observability, #102 (T-052; depends #100/#101)

Files: backend/internal/observability/guild_lifecycle, trace_http and exact
registration/guild edges; existing Grafana lifecycle panels and bounded metrics.

- [ ] Baseline implemented spans/counters; red tests for any uncovered parent trace,
  post-commit failure, conflict and hostile client OTLP attributes.
- [ ] Complete only missing source behavior; verify fixed event names, bounded
  metric outcomes, private user correlation and absence of bodies/password/raw names.
- [ ] Run exact Go tests, dashboard validators and scoped observable integration;
  record real trace IDs/counter deltas without publishing secrets or user content.

## Integration and review gate

- [ ] Inspect status/sizes, stage exact source files, commit per capability.
- [ ] Run complete native CI on integration SHA; fix failures and repeat checks.
- [ ] Attach any created PR, provide per-issue evidence and actual APK size delta.
- [ ] Record unavailable physical/platform checks accurately; preserve open gates.
