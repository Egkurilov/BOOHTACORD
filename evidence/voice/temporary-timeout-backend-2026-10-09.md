# Temporary voice timeout backend (#97)

Date: 2026-10-09. Scope: ADR023 server enforcement, additive migration0051,
secure-cookie admin API, and unchanged durable SFU revocation worker.

## Observed verification

- PASS: focused Go tests and vet for manage_voice_timeout, acquire_voice_lease,
  read_locked_voice_admission, issue_livekit_credential, authorize_livekit_signal
  and app/media_routes.
- PASS: WSL Go1.26.4 `go test -race` on 11 service/API/credential/signal/route
  packages. This invocation did not supply an integration database.
- PASS: actual PostgreSQL17, disposable database and isolated schemas;
  `go test -count=1 -v -timeout=180s ./internal/voice/manage_voice_timeout/postgres`:
  ten tests and two subtests, no skips, 154.273s.
- PASS: five concurrent Join/timeout rounds; legacy lease INSERT waits on the
  same lock then rejects; credential/signal wait and perform a fresh denial.
- PASS: session revocation, admin demotion/blocking, member mutation denial,
  self-only state privacy, duplicate request/audit behavior, database-clock
  expiry and manual lift never reactivate a revoked lease.
- PASS: injected audit constraint failure rolls back timeout, lease revocation
  and queue together. Existing durable worker survives synthetic SFU failure,
  timeout removal and later retry/confirmation.
- PASS: native contracts pipeline: 241 tool tests (one existing environment
  skip), 19 contract tests, 93 public operations and approved-brief hash/39
  requirement traceability. Public route count is independently extracted from
  Go bindings; drift/security/parameter mutation tests remain active.

## Acceptance still required

NOT_RUN: physical SFU disconnect latency, old-token replay against a real SFU,
and device microphone/capture behavior in QA10. The worker test uses a remover
stub and proves durable intent, not remote media removal. HTTP202 reports
committed intent and revocation_pending; it does not claim physical success.
Client administration binding is a separate implementation packet.

No production accounts, message/DM content, secrets or media were used or saved.
The disposable database remains available for other coordinated test packets.
