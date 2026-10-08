# IMP-19 / #93 post-commit journal decision

Route `review_gate`; leaf `chat/create_text_message/postgres` and exact journal
edges `realtime/event_hub`, `realtime/replay_event/postgres`.
Preserve message idempotence, current ACL rechecks, seven-day metadata hints,
boot epochs and resync behavior. Source manifest backend/go.mod.
Limits: tests <=120 lines each; unchanged behavior baselined by native journal
failure, restart, authorization and replay tests. No broker/exactly-once promise.

- [ ] Actual PostgreSQL fault: child commits via real TEXT store then exits before
  journal append; committed domain state remains queryable.
- [ ] Actual journal INSERT rejection after domain commit; require continuity
  loss/overflow, then epoch rotation on successful recovery.
- [ ] Verify foreign DM/blocked user/current ACL replay with native tests.
- [ ] Run nearest real PostgreSQL integration and native WS/journal tests.
- [ ] ADR-022 compares epoch/resync with transactional metadata outbox; retain
  epoch/resync invalidation hints and the existing durable voice revocation outbox.
- [ ] Record actual faults separately from device/production acceptance.

Stop: measured failure domain and documented delivery decision; no content logs.
Unresolved: source tests cannot prove production crash recovery or hardware gates.
