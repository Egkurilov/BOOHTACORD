# Guild lifecycle observability — #102

Status: isolated PostgreSQL/HTTP/OTLP integration PASS; production dashboard smoke
NOT_RUN. Existing server implementation was preserved and its missing network
export evidence added.

## Actual integration

`TestRealRegistrationDatabaseAndOTLPExport` runs migrations in a disposable schema,
enables a TEXT welcome target, sends a real registration HTTP request through the
production handler/service/repository, and reads the committed welcome from
PostgreSQL. The actual OpenTelemetry HTTP exporter sends protobuf to an isolated
HTTP collector; this is not merely an in-memory span-recorder assertion.

Recorded isolated trace: `d1e7ad284ff4c3b62b0485d55929377e`.
The trace is test evidence; it is not a production Tempo link.

- HTTP registration returns 201 and persists one SYSTEM_WELCOME.
- Export contains one registration HTTP root and one registration.welcome child,
  identical trace IDs, and the exact parent span ID.
- Server-created account ID correlates both spans; no synthetic login session is
  introduced. The child matches the committed message and configured channel IDs.
- Export contains no password or saved welcome body.
- Registration counter uses only its bounded outcome label.
- Existing outcome tests cover disabled/unavailable, database/phrase failures,
  committed registration with failed realtime publication, and fixed error text.
- Settings tests cover success/conflict/rejection and metadata-only audit.
- Hostile client OTLP tests reject forged server spans/events/identity attributes.
- Dashboard panels and sustained-failure alerts retain fixed queries and labels;
  normal disabled/unavailable outcomes are excluded from failure alerts.

## Checks

PASS: complete `go test ./...` with disposable PostgreSQL configured; focused guild,
registration, lifecycle, ingest sanitization and HTTP event suites; project
contracts; Python native checks (113 tests, one existing platform skip).
Web/Flutter client checks are recorded in their corresponding evidence files.

## Limits and privacy

No production rename, registration, account, message or welcome setting was
mutated for this check. Production Grafana/Tempo smoke and physical two-device
media checks remain NOT_RUN and cannot be closed by this isolated evidence.
User identity belongs only to existing private traces; it is absent from metric
labels, exported content, access logs and public UI error details.
