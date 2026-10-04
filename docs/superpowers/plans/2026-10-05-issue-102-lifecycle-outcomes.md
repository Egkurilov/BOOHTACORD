# Guild lifecycle outcome completion

> Execution: inline in this session, following the repository working method.
> Owner requested code-only merges; native tests, builds and smoke remain NOT_RUN.

**Goal:** Complete #102 outcome reporting without changing committed-operation responses.

**Architecture:** Existing #102 implementation (386cb4b9) remains authoritative.
Only authenticated settings rejection and missing post-commit publisher need runtime changes.
Registration already preserves the HTTP trace, server identity and committed account.

**Tech stack:** Go, PostgreSQL, OTel SDK, Prometheus, existing Grafana provisioning.

## Baseline and route

T-052 depends on T-010/T-014/T-044; registration dependency T-010 depends on T-003.
Scope is update_settings/api and registration_welcome/postgres, with exact composition
edge app/guild_routes/register.go and static trace_http events. No contract change.
Preserve secure session/administrator middleware, original forbidden response,
transactional welcome, fixed events, low-cardinality counters and private trace IDs.
Existing dashboards and sustained-failure alerts already implement the requested views.

## 1. Settings outcome tests before implementation

- [x] Add api/outcome_test.go and test fixture with real HTTP trace middleware,
  real Prometheus recorder and existing administrator middleware. Cover success,
  409 conflict, invalid channel, database failure, forbidden member and post-commit
  journal/nil-publisher failure. Assert one correlated child and one counter.
- [x] Assert raw guild name/driver error never enters spans, events or metric labels.

## 2. Settings runtime correction

- [x] Create api/post_commit.go and replace the inline publication block in patch.go:

```go
err = h.publishUpdate(ctx, result.Revision)
```

The helper returns eventhub.ErrJournalUnavailable for a missing publisher;
otherwise it publishes the existing revision-only hint with a detached 5s timeout.
Failure keeps HTTP 200 and db.committed=true, with failed/realtime child outcome.

- [x] Create api/rejected_updates.go: for an authenticated non-administrator,
  start guild.settings.update, finish rejected once and delegate to the existing
  RequireAdministrator response. In app/guild_routes/register.go wrap only PATCH:

```go
sessionapi.Require(sessions)(handler.ObserveRejectedUpdates(
  sessionapi.RequireAdministrator(http.HandlerFunc(handler.Patch))))
```

## 3. HTTP welcome and fixed-event evidence

- [x] Add registration_welcome/postgres/http_outcomes_test.go. Run the actual
  register service/API and trace middleware over the existing controlled transaction
  fixture. Cover published, disabled, unavailable channel, insert/phrase failure,
  realtime failure and missing publisher. Check parent/trace IDs, HTTP result,
  server-confirmed identity without session, static events and one bounded counter.
- [x] Add trace_http/guild_actions_test.go for name/welcome/both/unknown routes and
  200/400/409/500 status mapping. Never inspect raw values or derive event names.

## 4. Delivery and deferred verification

- [x] Update runbook with authenticated rejection and missing-publisher behavior.
- [x] Record source coverage and all unexecuted gates in evidence.
- [x] Inspect git status and exact changed file sizes.
- [ ] Commit selected files,
  push a semantic codex branch, attach PR and merge to master with [skip ci].
- [ ] Deferred native command: `cd backend && go test ./internal/guild/update_settings/... ./internal/identity/register_user/... ./internal/identity/registration_welcome/... ./internal/observability/...`.
- [ ] Deferred PostgreSQL fixture, dashboard JSON, contracts and promtool checks;
  production registration/rename smoke must supply actual trace IDs and screenshots.

Stop condition: code merged; #102 stays open until native and live evidence PASS.
