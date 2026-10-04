# Issue 102 — implementation evidence

Status: NOT_RUN (owner deferred scoped verification, builds and deployment).

Base: 22a22d85164b17eef8c7a2b39cffa6e697ea4cee.
Scope: #102 plus approved server dependencies of #100/#101.
Client settings/welcome rendering from #100/#101 is outside this server packet.

## Implemented

- Singleton guild profile/settings, revision update, active TEXT channel validation,
  metadata-only audit, post-commit revision hint and protected routes.
- Account + SYSTEM_WELCOME transaction, cryptographic fixed phrase selection,
  controlled skips, unique subject index, archive cleanup and message restrictions.
- Fixed HTTP actions, correlated child spans, successful registration identity
  without session, bounded Prometheus/OTel counters, sanitized failure details.
- Session-independent trace panel, runtime outcome/conflict/failure panels,
  sustained failure rules and operator runbook.

## Pending checks — NOT_RUN

```powershell
Set-Location backend
go test ./internal/guild/update_settings/... ./internal/identity/register_user/... ./internal/identity/registration_welcome/...
go test ./internal/channel/archive_text_channel/... ./internal/chat/create_text_message/... ./internal/chat/edit_text_message/... ./internal/chat/delete_text_message/...
go test ./internal/chat/list_text_messages/... ./internal/chat/search_text_messages/... ./internal/chat/search_messages/...
go test ./internal/observability/... ./internal/realtime/event_hub/... ./internal/realtime/replay_event/... ./internal/app/runtime/...
Set-Location ..
python -m json.tool docker/observability/dashboards/traces.json > $null
python -m json.tool docker/observability/dashboards/runtime.json > $null
pwsh -File tools/verify/contracts/verify-contracts.ps1
```

PostgreSQL cases require a disposable loopback VOICE_PLATFORM_TEST_DATABASE_URL;
the repository fixture creates its isolated schema and refuses unsafe hosts.
Run the runtime Linux-only route checks on the supported Linux validation host.
Validate rules with the pinned Prometheus promtool check rules before release.

## Production smoke — NOT_RUN

- Administrator rename, revision hint and conflict HTTP 409.
- Register with welcome enabled, disabled and channel unavailable.
- Verify the server HTTP and welcome child share one trace and actual user ID.
- Verify no synthetic session ID before login.
- Inject realtime publication failure after DB commit in a disposable environment.
- Inspect dashboard links/filters and privacy/cardinality boundaries.

Trace IDs: NOT_RUN. Grafana screenshots: NOT_RUN. Failure-rule live proof: NOT_RUN.
No build, CI workflow, deployment or production registration was launched.
Code merge is not release/physical acceptance evidence.
