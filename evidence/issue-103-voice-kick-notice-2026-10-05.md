# Issue #103 — semantic voice termination

Status: NOT_RUN. Owner requested code-only merging; focused/native tests,
visual/device acceptance, builds and deployment are deferred to a grouped run.

## Source changes

Web and Flutter use structured terminal notices with server > explicit local
leave > transport precedence. Lease/channel identity is retained locally after
media teardown; a matching late KICK can replace a tentative transport notice.
Foreign leases and events from an earlier join/account generation are ignored.
Duplicate server delivery does not change the notice or emit another outcome.
Pending admission matches its exact lease; known revocation never resumes media.

KICK shows the administrator text and stopped-auto-reconnect explanation,
with microphone/listener manual join available after cleanup. CHANNEL_CLOSED,
BANNED and ended sessions disable join; TRANSFER and transport loss retain
separate copy. Existing admissionClosed/server ACL checks remain authoritative.
Notice clears at a new explicit join, another selected channel, or account
teardown; selecting another channel during teardown still cleans old media.
The notice uses status/live region on Web and Semantics(liveRegion:true) native.

Existing kick API/payload remain unchanged. A new PostgreSQL integration test
runs the actual kick repository, notification claim/mark service and addressed
hub dispatch, asserting KICK only reaches the target and duplicate kick queues
nothing. The test publisher adapter implements the durable publisher port with
an in-memory hub; durable journal persistence/retry tests remain existing gates.

## Observability

Reconnect ending because the room terminated is marked interrupted, without
app.client.voice.reconnect.failed. Terminal voice.disconnect emits only bounded
reason/source/platform and boolean reconnect_allowed; the Go relay validates
source/reason pairing and derives reconnect policy, stripping all other attrs.
A server outcome commits once immediately. Tentative local/transport outcomes
commit at the next explicit join/channel/session boundary so a late addressed
revocation can provide the single semantic outcome first. An abrupt process kill
may therefore lose an uncommitted tentative diagnostic; live UI updates at once.

## Authored focused tests (all NOT_RUN)

- Web terminal state, both store event orders, pending join, duplicate delivery,
  successful leave race, changed selection during cleanup, SSR genuine prejoin
  copy/action gating/live status, interrupted reconnect without failed event.
- Flutter terminal model, both actual controller callback orders, pending join,
  foreign/stale lease, local exit, changed selection during pending admission,
  reason-aware manual actions and notice semantics.
- Go closed attribute policy, relay/event privacy, real Postgres kick -> KICK ->
  target-only hub delivery and duplicate behavior.

## Deferred commands

Web: npm test -- disconnect_notice voice_lease_revocation connection_lifecycle
Flutter: flutter test test/voice_disconnect_notice_test.dart test/voice_disconnect_race_test.dart test/voice_disconnect_notice_widget_test.dart test/voice_scope/admission_test.dart test/voice_lease_revocation_test.dart
Go: go test ./internal/observability/ingest_client_traces/... ./internal/voice/kick_voice_participant/... ./internal/voice/notify_lease_revocation/...
The PostgreSQL test uses VOICE_PLATFORM_TEST_DATABASE_URL and the existing
isolated-schema loopback fixture. Missing DB means NOT_RUN, not a passed gate.
Include native type analysis/lint in the grouped run; no release artifacts now.

## Visual/device protocol (all NOT_RUN)

Web 1440px/1024px, Android portrait, Windows desktop, iOS available macOS/physical
runner: connect two users, admin-kick one, exercise both realtime/LiveKit orders,
reconnect exhaustion before/after KICK, duplicate delivery and pending join/leave.
Confirm the exact primary/explanatory text, one semantic live announcement,
manual microphone/listener actions and no auto-rejoin. Exercise channel closure,
ban, session revocation/logout, transfer and actual network failure separately.
Select another channel/new join/logout: no stale notice or old room callback.
Verify media/screen cleanup and authorized manual rejoin; record sanitized
semantic trace with no identifiers/tokens or false reconnect.failed outcome.

Keep #103 open until focused and visual/device evidence records PASS.
