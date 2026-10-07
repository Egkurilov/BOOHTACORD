# Media sample contract implementation plan

> Agentic execution: root owns the server/report/relay leaf; the #159 agent owns Web/Flutter collection. Their work is combined before delivery.

**Goal:** Keep bounded interval and provenance fields from actual client collection through validated reports and private flow traces.

**Architecture:** Extend the existing optional report with an embedded measurement value. Reuse its relationship validator in the versioned relay. Generate all three client/server allowlists from the canonical telemetry JSON, preserving legacy reports and the 32 attribute ceiling.

**Tech stack:** Go, OpenAPI 3.1, OTLP, generated TypeScript/Dart field tables.

## Server report and evidence

- [x] Add `backend/internal/observability/report_client_screen/measurement/report_test.go` with absent legacy fields, bounded durations, wrong directions, unsupported sources and missing/zero windows. Confirm missing `Report` gives the initial compile failure.
- [x] Define optional numeric counters and bounded source/state enums in `measurement/report.go`; implement `measurement/validate.go` with `StatsWindowMs > 0`, source matching and sender/receiver ownership.
- [x] Embed the measurement value in `backend/internal/observability/http_metrics/client_screen_report.go`; keep existing validation and public field shape.
- [x] Test strict POST decoding, rejected private layer identity, preserved totals and omitted legacy fields in `report_client_screen/api/measurement_test.go`.
- [x] Export only validated numeric/enumerated attributes through `api/record_measurement.go` and the existing trusted server `media.sample` span.

## Relay and generated contracts

- [x] Add `measurement/flow.go` to apply the same relationships to fixed `app.media.*` fields in `ingest_client_traces/flow_attributes.go`.
- [x] Add safe pipeline and unsupported-source rejection tests in `ingest_client_traces/media_intervals_test.go`.
- [x] Extend `contracts/openapi.yaml` and `contracts/telemetry-flow-v1.json`, then run `node tools/observability/flow_contract/generate.mjs`.
- [ ] Run `go test ./internal/observability/flow_contract ./internal/observability/ingest_client_traces ./internal/observability/report_client_screen/... ./internal/observability/http_metrics` from `backend`, then `python -m tools.ci.native.contracts` from root. Require PASS, keep the existing documented Python skip explicit.
- [ ] Combine client collection with the exact server commit, verify generated tables with `node tools/observability/flow_contract/generate.mjs --check`, run focused client tests and CI no-skip backend tests. Physical paired measurements remain NOT_RUN until executed.
