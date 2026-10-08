# IMP-19 / #93 actual post-commit faults

Source base: integration commit `38ec4885439119fd7ea6012e764e1162e116a896`.
Environment: Windows native Go 1.26.4, SSH tunnel to an isolated disposable
PostgreSQL 17 database on a development host, unique schema per fixture.
Production domain data, sessions and voice/media services were not mutated.

PASS: `TestActualPostCommitCrashAndJournalFailureRequireResync` (12.53 s).
The child invoked the real TEXT service/repository and exited with code 73 after
the real committed SQL statement, before journal append. Parent verified one
domain record and zero message.created hints. A new hub rejected the old cursor
with ErrDifferentEpoch. An isolated PostgreSQL constraint then rejected a real
journal INSERT after a second domain commit: two records, zero created hints,
continuity false, connected subscriber overflow signal. Removing the fault and
publishing a valid hint rotated the epoch. Fixture cleaned its schema afterward.
Credential/config only passed privately via environment; child output discarded.
Synthetic body/identities were not included in evidence or command output.

PASS: real `TestJournalMigrationReplayAndCurrentACL` (5.11 s): persisted hint
replay, deduplication, wrong epoch, foreign DM cursor/ACL denial, blocked user
revocation, expiry. PASS: complete native event_hub and connect_session packages,
including actual WebSocket resync/replay/session revocation paths. Native vet PASS.

ADR-022 keeps existing epoch/resync UI hints and security revocation outbox;
therefore no generic transactional outbox implementation was selected.
Device/production crash, socket reconnect and authoritative UI rebuild: NOT_RUN.
Those acceptance scenarios must use a disposable release stack or approved
production smoke and preserve no-DM-leak and no-automatic-microphone invariants.
