# ADR-022: post-commit invalidation hints and authoritative resync

Status: accepted engineering decision for #93, 2026-10-08.

## Measured failure domain

Real PostgreSQL TEXT writes commit before post-commit journal append. A child
process terminated at that exact boundary leaves one durable message and no
message.created hint. A real rejected journal INSERT after another domain commit
leaves the domain operation successful, breaks continuity, and signals connected
subscribers to resync. Recovery rotates the epoch. A new process rejects a cursor
from the previous epoch. Current DM/blocked-account ACL checks remain mandatory.

## Alternatives

| Choice | Guarantee | Cost / limitation |
|---|---|---|
| Epoch/resync | Authoritative state survives; uncertain continuity requires a new HTTP state read | A committed invalidation hint can be missing; reconnect requires resync |
| Transactional metadata outbox | Intent persists atomically with each domain mutation; worker retries publish | Every producer needs transaction wiring, retention/worker/dedupe; WS delivery still requires reconnect/ACL |

## Decision

Keep epoch/resync for recoverable UI invalidation hints. Clients read authoritative
HTTP history/profile/channel state after resync; the journal is a bounded replay
optimization, not the sole domain record. Do not add an outbox to all mutations
without a requirement for durable per-event external processing. Never acknowledge
uncertain journal continuity as a complete replay; preserve overflow/restart handling.
Domain response/idempotency remains independent of post-commit hint delivery.

Keep the existing transactional voice-revocation outbox: those security side
effects must be retried independently until the SFU revoke succeeds. Its private
recipient hints, current session/ACL rechecks and deduplication remain intact.

No exactly-once WebSocket promise, message body in journal/logs, default broker,
Redis or additional infrastructure. A future durable consumer requirement must
revisit this ADR and transaction boundaries. Real production crash/device recovery
remains separate QA; isolated PostgreSQL faults do not prove that release gate.
