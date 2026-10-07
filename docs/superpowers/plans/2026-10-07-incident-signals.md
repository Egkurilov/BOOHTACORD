# Incident signals Implementation Plan

> **For agentic workers:** Execute scoped packets inline under the existing subagent assignment.

**Goal:** Diagnose HTTP, pool, workers and dependency failures without private labels or content logs.

**Architecture:** Keep HTTP metrics behind the existing Recorder binding; a dedicated route leaf owns fixed labels. Observe pool acquisition with pgxpool's native tracer and expose live pool stats. A fixed operation signal leaf records only elapsed time, bounded outcome, and dependency timestamps; existing media/realtime signals remain authoritative.

**Tech Stack:** Go 1.26, pgxpool v5, Prometheus, OTel, Grafana JSON.

Operating brief: workflow_class=split_first; size=large; structure_no_rg.
Active doctrine: AGENTS.md/SKILL.md/native manifests; 100 target/120 hard lines.
Route packets: observe_http_requests, database/pool, observe_incidents; exact native bindings only.
Baseline: method/status counters, server UUID request IDs, operational span/log exclusion, existing roster/media/storage/realtime signals preserved.
Checks: focused Go tests then compile/vet touched packages; traceability only if backlog/contracts change.
Stop: all requested safe signals + operator/dashboard guidance committed in issue branch; runtime acceptance NOT_RUN.

### Packet 1: HTTP routes and correlation

Files: new `backend/internal/observability/observe_http_requests/{metrics,labels}.go` and focused tests;
modify `http_metrics/{recorder,request_middleware,logging_middleware}.go`, `trace_http/middleware.go`, `app/runtime/routes.go`.

- [x] Write a failing route test: registered `GET /items/{id}` receives `/items/private?token=secret`; scrape must contain route template, GET, 503 and no private/secret; 100 arbitrary unknown methods/paths must collapse to OTHER/unmatched.
```go
mux.HandleFunc("GET /items/{id}", func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(503) })
```
- [x] Add a failing panic test (counter 500 and panic rethrown) and excluded-route aggregate 401/503 test with no logs/spans.
- [x] Add request-ID trace test using `requestid.Middleware`; span attribute must equal response UUID, never client header.
- [x] Implement route vectors with labels method,route,status; fixed operation enums for excluded paths; resolve template before Origin rejection via mux.Handler.
```go
_, pattern := mux.Handler(request)
```
- [x] Preserve Upgrade interfaces and first response status; bound method to standard enum and status to valid HTTP integers.
- [x] Run `go test ./internal/observability/observe_http_requests ./internal/observability/http_metrics ./internal/observability/trace_http ./internal/app/runtime`.

### Packet 2: Native database pool observations

Files: `backend/internal/database/pool/{open,tracer,metrics,export}.go` and focused tests; `app/runtime/run.go` registration.

- [x] Write tracer failure/timeout/cancel tests; verify private connection error never enters scrape.
```go
tracer.TraceAcquireEnd(ctx, pool, pgxpool.TraceAcquireEndData{Err: context.DeadlineExceeded})
```
- [x] Implement optional observed Open with native AcquireTracer/QueryTracer, monotonic acquire histogram, fixed success/failure/timeout/canceled outcomes, pending gauge, live acquired/idle/total/max connections and cumulative empty acquire wait.
- [x] Register only the actual runtime pool into existing Recorder registry; preserve Open and pool.Ping behavior.
- [x] Run `go test ./internal/database/pool` and nearest runtime tests.

### Packet 3: Operation incidents and dependency freshness

Files: new `backend/internal/observability/observe_incidents/{metrics,outcome,exports}.go` plus tests;
exact bindings: workers `channel/finalize_closed_voice_channel/worker`, `voice/notify_lease_revocation/worker`, `media/dispatch_voice_sfu_revocation/worker`; realtime `event_hub/durable.go`; LiveKit `snapshot_livekit_presence/observer.go`; OTel `start_tracing/provider.go`, `start_metrics/provider.go`; relay `ingest_client_traces/handler.go`; filesystem/LiveKit collector snapshot adapters.

- [x] Write fixed enum rejection and freshness tests (success then failure retains last-success, last-result fails; unobserved remains absent).
```go
signals.Observe("livekit_snapshot", time.Millisecond, errors.New("private"))
```
- [x] Implement Prometheus operation count/histogram and last-attempt/success/result; stale follows last successful attempt with operation-specific threshold in dashboard.
- [x] Add named fixed outcome signals around worker calls, journal append, LiveKit transport, relay export and exporter wrappers; no error text, IDs, content or arbitrary labels.
- [x] Keep existing outcome counters, snapshots and span instrumentation; signal snapshots at validation boundary.
- [x] Run focused tests for each touched leaf and OTel exporter failure tests.

### Packet 4: Operator artifacts and handoff

Files: `docs/observability/incident-signals.md`, `docker/observability/dashboards/incidents.json`, this plan.

- [x] Document each excluded path's aggregate, existing equivalents, stream-duration interpretation and /metrics self-observation delay; request-ID lookup plus sampling limitations, bounded pool/operation outcomes and absent versus zero.
- [x] Build separate incident dashboard with 5xx/p95 by template, scrape timestamp/age/up/absent, dependency success timestamp/age/failure/absent, pool saturation/wait/pending and worker/export failure counters; no `or vector(0)` and no null-as-zero.
- [x] Record focused validation and honest NOT_RUN physical/runtime findings.
- [ ] Inspect status/diff/file sizes; stage exact files, commit, push and create PR to master with Refs #5; root performs review/merge.
