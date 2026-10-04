# Voice Kick Notice Implementation Plan

> Execute inline: owner authorized code-only merge; native/visual checks are deferred.

**Goal:** Preserve the semantic voice termination reason for both realtime/LiveKit orders across Web and native clients.

**Architecture:** A bounded terminal model retains lease/channel identity until a new explicit join, channel selection or account teardown. Server > local leave > transport. Repeated server delivery is idempotent. UI renders the structured notice and gates manual join by reason. Reconnect traces interrupted by termination never emit a misleading failed event; terminal telemetry commits a server outcome once, and tentative transport/local outcomes at the next explicit boundary.

**Tech Stack:** Vue/Pinia/TypeScript, Flutter/Dart/LiveKit, existing Go kick and authenticated OTLP relay.

Operating brief: split_first; T-022 depends T-006/T-020; preserve lease ACL, media cleanup, screen/deafen lifecycle and native admission policy. One terminal-disconnect trigger family per leaf; new source target100/hard120 lines, target8/hard16 source/test files. Existing oversized UI/store/state receive thin native bindings only.

## 1. Tests before implementation

Checkboxes track authored work only; execution remains NOT_RUN.

- [x] Create Web terminal model and store race tests for both orders, pending join/leave, duplicate delivery, stale lease/new join, source priority and reset.
- [x] Create native model/controller/widget tests for the same orders and reconnect button availability.
- [x] Add Go telemetry privacy tests and an existing PostgreSQL integration fixture for admin kick -> KICK -> only-targeted realtime event; contract stays identical.

Expected model assertions:
```ts
terminal.bind('lease', 'channel')
terminal.transport()
terminal.server('lease', 'KICK')
expect(terminal.notice.value?.reason).toBe('KICK')
expect(terminal.notice.value?.reconnectAllowed).toBe(true)
terminal.transport()
expect(terminal.notice.value?.source).toBe('server')
```

## 2. Web leaf and exact bindings

Create src/voice/disconnect_notice/{model,state,reporting,Notice}. Bind connection_store, connection_lifecycle, voice_connection_revocation and voice_connection_leave to shared terminal state. Retain lease after transport/leave, accept only matching late events, reset on explicit join/channel/account boundaries. Guard asynchronous completion by terminal generation. Rewire old revocation entry as a forwarding wrapper if split required. Keep source priorities in the model, not string comparisons.

Wire WorkspaceMain -> ConversationPane -> VoicePrejoin with notice; KICK displays administrator text plus stopped-auto-reconnect explanation and both enabled manual join modes. CHANNEL_CLOSED blocks matching channel, BANNED/session-ended blocks join, TRANSFER and network loss have separate copy. Dock keeps a compact copy without a second live announcement. Clear authenticated stores still dispose terminal state.

## 3. Native leaf and exact bindings

Create features/voice/disconnect_notice/{model,state,telemetry,control}. Bind lifecycle state/controller, lease_events/revocation, connection_close/disconnect/leave, admission/join and room_events/connection. Preserve last lease before room becomes null and accept the matching late revocation. Pending join records only exact admitted lease. Update app/media_access/voice_controls and workspace selection boundary. Extract notice widget; prejoin actions remain existing join callbacks with reason-aware enablement and Semantics(liveRegion:true).

## 4. Closed telemetry and evidence

Add voice.disconnect to relay whitelist with only bounded reason/source/platform and boolean reconnect_allowed. No lease/channel/account IDs or free text. End interrupted reconnect span without app.client.voice.reconnect.failed; publish one semantic termination outcome.

Add evidence/issue-103-voice-kick-notice-2026-10-05.md with NOT_RUN native/visual gates and exact deferred commands. Required visual runs: Web1440/1024, Androidportrait, Windowsdesktop, physical iOSrunner. Both event orders, duplicate delivery, local leave, explicit rejoin/channel change/logout, other revocation reasons and ordinary network loss.

## 5. Handoff

Inspect source diff/status/candidate sizes, sync master, commit/push/merge [skip ci]. Do not close #103 until focused and visual/device checks PASS. No builds/deployment in this packet.

Deferred checks: Web npm test -- disconnect_notice voice_lease_revocation connection_lifecycle voice_reconnect_monitor; Flutter flutter test test/voice_disconnect_notice_test.dart test/voice_disconnect_race_test.dart test/voice_disconnect_notice_widget_test.dart test/voice_scope/admission_test.dart; Go go test ./internal/voice/kick_voice_participant/... ./internal/observability/ingest_client_traces/... and ./internal/voice/notify_lease_revocation/... with the documented loopback PostgreSQL fixture.
