# Issue #102 — outcome completion

Status: NOT_RUN. Owner requested code-only merging; verification, builds,
deployment and production smoke remain deferred to a grouped run.
Base: c3c03a5997652825b20c4dcae4924b73bc9afccf.

## Existing implementation

386cb4b9 already supplied the server dependencies of #100/#101, correlated
registration/welcome and settings spans, static HTTP events, bounded Prometheus
and OTel counters, Grafana lifecycle/outcome panels and sustained failure rules.
The original evidence remains evidence/2026-10-04-issue-102-guild-lifecycle.md.
Client settings/rendering from #100/#101 are outside the approved server packet.

## Additional runtime changes

- Missing settings publisher now emits failed/realtime with db.committed=true;
  committed settings still return HTTP 200. No false delivery success.
- An authenticated non-administrator PATCH produces one rejected settings child
  and counter before the existing administrator gate returns its existing 403.
  The store is not reached. Unauthenticated requests remain session refusals.
- Extracted the existing post-commit timeout/revision-only hint into an API leaf
  helper. Session, ACL, CSRF/Origin, HTTP contract and database behavior are kept.

## Authored checks — NOT_RUN

- Actual settings handler + HTTP trace middleware + real Prometheus recorder:
  success/conflict/channel/database/realtime/missing publisher/member refusal;
  one child, actor/session/revision, static HTTP event and one outcome counter.
- Actual registration service/API + HTTP middleware over the controlled database
  transaction fixture: published/disabled/unavailable/insert/phrase selection/
  realtime/missing publisher. Check HTTP 201 after commit, 500 before commit,
  parent/trace identity, server-created account, absent pre-login session,
  fixed outcome events and low-cardinality Prometheus labels.
- Actual OTel metric SDK manual reader: unknown outcome normalizes to failed,
  finishing twice counts once, only outcome label, no identity metric resource.
- Fixed guild name/welcome/both event presence across 200/400/409/500;
  unknown routes emit no lifecycle event.
- Negative signal assertions exclude password, raw guild name, raw driver error,
  username and entity IDs from inappropriate signals. Existing OTLP spoofing
  tests and PostgreSQL transaction/ACL cases remain required grouped gates.

The new HTTP registration matrix uses a controlled transaction fixture;
it is not live PostgreSQL or Grafana evidence. Source formatting only ran.

## Deferred native checks

```powershell
Set-Location backend
go test ./internal/guild/update_settings/... ./internal/identity/register_user/... ./internal/identity/registration_welcome/... ./internal/observability/...
Set-Location ..
python -m json.tool docker/observability/dashboards/traces.json
python -m json.tool docker/observability/dashboards/runtime.json
pwsh -File tools/verify/contracts/verify-contracts.ps1
```

Use the existing disposable loopback VOICE_PLATFORM_TEST_DATABASE_URL for
PostgreSQL cases and the supported Linux validation host for runtime route gates.
Run pinned Prometheus promtool check rules and the original smoke protocol:
rename/conflict, registration outcomes, controlled post-commit failure, real
trace IDs and Grafana screenshots. Compare both counter exports and inspect
resource/label privacy. No deployment mutation or registration was performed.

Trace IDs: NOT_RUN. Dashboard live queries/screenshots: NOT_RUN.
Production smoke: NOT_RUN. Keep #102 open until these acceptance gates PASS.
