# Plan: #268 roster SSE failure classification and recovery

**Route:** `backend/internal/voice/watch_connected_participants` (leaf SSE handler), with the existing `list_connected_participants` service as the snapshot error boundary and `http_metrics` as the bounded telemetry sink.
**Packet:** #268 source implementation only. Preserve the current authenticated route, ACL rechecks, initial 5s timeout, session revalidation cadence, notification/reconciliation cadence, heartbeat, and webhook behavior.
**Contract:** initial snapshot errors remain non-200 and generic; auth/ACL status handling remains owned by the existing session middleware/service. After SSE starts, a failed roster refresh writes `event: roster-unavailable` with `data: {}` and closes. It must never serialize an error as `channels: []`, reveal identifiers/raw dependency errors, or use `session-expired` for roster failures. Successful empty snapshots continue to use the ordinary unnamed `data: {"channels":[]}` message.

## Steps

1. Add focused failing handler tests in a new responsibility-sized test file for: initial failure is non-200/generic; post-handshake refresh failure emits exactly the bounded unavailable event then closes; it does not emit an empty roster or session-expired; observer receives a bounded failure stage; successful empty inventory remains an ordinary roster message. Use a sentinel error containing private-looking text to prove it is not serialized.
2. Split the current oversized SSE handler file along the handler setup and stream lifecycle boundary while retaining the existing behavior. Keep each changed production/test file at or below the 120-line hard ratchet. Keep the SSE loop and event writers small and responsibility-focused.
3. Add an optional bounded stream-failure observer to the handler and wire the existing Prometheus recorder at the composition edge. Permit only fixed stage names (stream snapshot/session-store/write and bounded operation timeout/cancel stages) in the existing roster failure metric; raw errors and request/account/channel/session values must never become labels. Keep the existing SFU method/outcome counters for room-list versus participant-list failures.
4. On notifier/reconciliation snapshot error, emit the bounded unavailable SSE event and close. Keep auth revocation/mismatch on `session-expired`; keep session-store revalidation failures closing without roster data; client cancellation remains a normal close and is excluded from dependency failure metrics, while deadline expiry remains a bounded timeout failure. Do not add retry loops or alter cadence; EventSource/client recovery remains the established reconnect mechanism.
5. Run focused watcher tests, relevant service/metrics tests, broader Go tests for the affected packages, contract verification, formatting, and diff/ratchet checks. Review the diff for exact changed-file line counts and confirm no OpenAPI/client schema change is required by this event-only addition.

## Stop conditions

- Stop rather than downgrade a failed snapshot to an empty roster.
- If a dependency failure cannot be distinguished without changing current service/security semantics, retain its current safe generic behavior and document that boundary.
- Leave #268 open until its full source checklist is implemented; physical/runtime QA is outside this packet.
