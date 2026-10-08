# Temporary voice timeout (#97)

Route: split_first; leaf voice/manage_voice_timeout, its postgres/api adapters;
admission edges acquire_voice_lease, issue_livekit_credential, authorize_livekit_signal.
Doctrine: preserve fixed roles, sessions, TEXT/DM ACL and durable SFU revocation.
Ratchet: target100/hard120 physical lines; target8/hard16 files per child leaf.
Stop: local clean commit, native checks and bounded integration evidence; no push.

## Policy and acceptance

ADR023 defines database-clock expiry, maximum24h, bounded reason codes and server
admin/session checks. Only self/admin can read state. Set revokes current leases
and enqueues existing physical SFU revocations in the same transaction.202 means
committed intent, never confirmed physical removal. Clear/expiry never restore a
lease, cancel an outbox item, join media or unmute. No permanent role system.

## Implementation checklist

- [x] Write focused service/API tests before implementation: validation, session,
  member denial, JSON privacy, GET self/admin and conflict mapping.
- [x] Add migration0051_create_voice_timeouts.sql: table plus additive legacy
  lease-insert guard. Guard acquires existing account advisory lock and checks
  expires_at > clock_timestamp(); it must not alter text, DM or session data.
- [x] Implement voice/manage_voice_timeout service, postgres child split into
  begin/ACL, reads, set SQL and clear SQL under120 lines. Lock actor/target in
  sorted order. Recheck actor session/admin inside transaction. Set writes audit,
  lease KICK and durable queue with causal reference, idempotently.
- [x] Add API PUT/DELETE /admin/accounts/{accountID}/voice-timeout and GET
  /accounts/{accountID}/voice-timeout using existing session middleware. Admin
  mutations use existing global Origin/CSRF controls. No reason free text.
- [x] Add CheckVoiceTimeout to acquisition transaction after account lock;
  propagate ErrVoiceTimeout to409 VOICE_TIMEOUT. Keep existing fake row order.
- [x] Add child media/read_locked_voice_admission: pgx row wrapper Scan begins
  transaction, resolves lease owner if needed, locks account then reads current
  admission at READ COMMITTED. Wire existing credential/signal PoolDatabase only.
- [x] Add NOT EXISTS active timeout to credential and signal SQL. Preserve their
  existing denial contracts. Old tokens cannot regain revoked lease access.
- [x] Real PG tests: member ACL/session revoke/self-read privacy; set idempotence;
  expiry/manual clear; admission races; outbox fault/retry; direct legacy insert.
- [x] Update OpenAPI, ADR023, backlog IMP44 and evidence without closing QA gates.

## Native checks

Run from backend: go test ./internal/voice/manage_voice_timeout/...
./internal/voice/acquire_voice_lease/... ./internal/media/read_locked_voice_admission/...
./internal/media/issue_livekit_credential/... ./internal/media/authorize_livekit_signal/...
./internal/app/media_routes; then go vet same packages. Run focused race tests
with WSL Go. Use isolated PG17 fixture and VOICE_PLATFORM_TEST_DATABASE_URL;
never print DSN. Run tools/verify/contracts/verify-contracts.ps1 and
tools/verify/spec_traceability/verify-spec-traceability.ps1. Inspect changed sizes/status before stage.

Physical live SFU/device acceptance and client administrator binding are separate
follow-up packets; synthetic tests do not establish production capacity.
