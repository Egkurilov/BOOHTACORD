# OTel session correlation implementation plan

> Execution: inline in the existing isolated worktree; review each packet before deployment.

**Goal:** Make Grafana show an authenticated user's sessions and actions across independent traces.

**Architecture:** Preserve W3C trace ancestry for each action. Add verified `user.id` and a domain-separated, non-authenticating `session.id` to API spans after authentication. Group returned request spans in Grafana and link each session to a filtered request timeline. Client spans remain sanitized; a trace containing a correlated API span links the client action without attributing delayed client batches to a later login.

**Tech stack:** Go OTel SDK, Grafana 13.0.2, Tempo 2.10.3, GitHub Actions.

## Review packet

- [x] Route: T-052; dependencies T-010, T-014, T-044; nearest capability is authenticated HTTP trace correlation.
- [x] Baseline: HTTP spans have method, route and status only; W3C links already work for voice.join.
- [x] Dashboard defects: raw request list dominates, client service filter omits native platforms, background voice workers dominate voice panels, WebSocket lifetime appears as slow HTTP latency.
- [x] Preserve ACL, cookie validation, sanitized client metadata, low-cardinality metrics and per-action trace duration.
- [x] No session token/digest, usernames, message/DM IDs or content may be exported. `user.id` is the verified opaque account ID.

## Packet 1: Correlate authenticated request spans

Files: `backend/internal/observability/correlate_session/attributes.go`, `attributes_test.go`, `backend/internal/identity/authenticate_session/api/middleware.go`, `trace_correlation_test.go`.

- [ ] Write tests before implementation: equal account/session yields equal IDs; a different digest yields a different session ID; zero digest yields no session ID; session digest is absent from output; forged headers cannot override the authenticated principal; failed authentication adds no identity.
- [ ] Run `go test ./internal/observability/correlate_session ./internal/identity/authenticate_session/api` and observe failure before implementing.
- [ ] Implement `Attributes(accountID string, digest [32]byte) []attribute.KeyValue`: emit `user.id`; when digest is nonzero, emit 16-byte hexadecimal SHA-256 of `boohtacord/otel/session/v1\x00 + accountID + \x00 + digest` as `session.id`.
- [ ] Make both Require and Optional call WithPrincipal; WithPrincipal sets these attributes on the current span, then stores the unchanged Principal.
- [ ] Run focused tests and `go test ./internal/observability/... ./internal/identity/authenticate_session/...`; run `go vet` for affected packages.

## Packet 2: Make the dashboard navigable

Files: `docker/observability/dashboards/traces.json`, `scripts/observability/test_traces_dashboard.py`, `docs/OBSERVABILITY_TRACES.md`.

- [ ] Add dashboard contract tests: query variables `user`/`session` use Tempo span labels; summary selects and groups by `span.user.id` and `span.session.id`; data link sets session filter; native platforms are included; slow requests exclude the WebSocket route.
- [ ] Run `python -m unittest scripts.observability.test_traces_dashboard` before dashboard edits.
- [ ] Add user/session dropdowns with All selected. Use `${user:regex}` and `${session:regex}` in TraceQL. Select server spans with `select(span.user.id, span.session.id, span.http.route, span.http.response.status_code)` and `tableType: spans`.
- [ ] Group the session summary by user/session, counting returned spans and showing last activity plus mean/max request duration. Label aggregates as a bounded search sample, not exact total traffic.
- [ ] Put filtered requests and client actions below the summary. Use trace-level intersection to find client actions belonging to correlated API traces. Keep unattributed/background traces in a collapsed diagnostics row.
- [ ] Run dashboard tests and send generated queries to the deployed Tempo parser. Verify actual Grafana field names and links in the browser.

## Packet 3: Delivery and live evidence

- [ ] Inspect changed files, sizes and diff; commit exact files. Integrate with current GitHub master without overwriting concurrent changes.
- [ ] Wait for required backend, frontend and release guards, then verify successful production deployment.
- [ ] Update the existing Grafana dashboard with the reviewed JSON and verify saved UI, session grouping and drilldown against fresh authenticated traffic.
- [ ] Record the source commit, workflow, live correlated span counts and any limits in `evidence/release/`.

Stop condition: deployed API spans correlate safely by account/session, Grafana shows one row per session with working drilldown, and native tests plus live checks pass. Old traces have no retroactive identity.
