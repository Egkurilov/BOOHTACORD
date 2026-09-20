# Private HTTP Metrics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expose low-cardinality API request count and latency Prometheus metrics only on the private API network, without breaking WebSocket upgrades or leaking user/content identifiers.

**Architecture:** A per-process Prometheus registry owns `voice_platform_api_requests_total` and `voice_platform_api_request_duration_seconds`, labeled only by HTTP method and integer status. Its middleware wraps all API routes while preserving `Hijacker`, `Flusher`, `Pusher`, `ReaderFrom`, and `Unwrap` capabilities needed by WebSocket and streaming handlers. The API serves `/metrics` internally; Caddy explicitly returns 404 for the public `/metrics` path rather than falling back to the Vue app.

**Tech Stack:** Go 1.26, Prometheus client_golang, Caddy, Docker Compose private network.

---

### Task 1: Write failing metrics behavior tests

**Files:**
- Create: `backend/internal/observability/http_metrics/recorder_test.go`
- Test: `backend/internal/observability/http_metrics/recorder_test.go`

- [ ] **Step 1: Add a request metric scrape test**

```go
recorder := New()
wrapped := recorder.Middleware(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
	w.WriteHeader(http.StatusCreated)
}))
wrapped.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest(http.MethodPost, "/api/v1/channels/secret-id", nil))

scrape := httptest.NewRecorder()
recorder.Handler().ServeHTTP(scrape, httptest.NewRequest(http.MethodGet, "/metrics", nil))
if !strings.Contains(scrape.Body.String(), `voice_platform_api_requests_total{method="POST",status="201"} 1`) {
	t.Fatal("expected POST/201 counter")
}
if strings.Contains(scrape.Body.String(), "secret-id") || strings.Contains(scrape.Body.String(), "path=") {
	t.Fatal("metrics must not expose request paths or identifiers")
}
```

- [ ] **Step 2: Add a transport-capability preservation test**

Use a fake `http.ResponseWriter` implementing `http.Hijacker`, `http.Flusher`, `http.Pusher`, and `io.ReaderFrom`; assert the wrapped writer supplied to the next handler implements the same interfaces and `interface{ Unwrap() http.ResponseWriter }`.

- [ ] **Step 3: Run the package test before implementation**

Run: `go test ./internal/observability/http_metrics -count=1`

Expected: `FAIL` because the package does not exist.

### Task 2: Implement the private recorder

**Files:**
- Create: `backend/internal/observability/http_metrics/recorder.go`
- Modify: `backend/go.mod`

- [ ] **Step 1: Construct a private registry and handler**

Register exactly these metric vectors:

```go
prometheus.NewCounterVec(prometheus.CounterOpts{Name: "voice_platform_api_requests_total"}, []string{"method", "status"})
prometheus.NewHistogramVec(prometheus.HistogramOpts{Name: "voice_platform_api_request_duration_seconds"}, []string{"method", "status"})
```

Use `promhttp.HandlerFor(registry, promhttp.HandlerOpts{})`; do not use global registration.

- [ ] **Step 2: Record method/status/duration and preserve upgrades**

Default an unwritten status to `200`, measure with `time.Since`, and skip `/metrics` itself. Implement all optional HTTP interfaces as delegations to the original response writer; return `http.ErrNotSupported` when an optional interface is unavailable.

- [ ] **Step 3: Make Prometheus a direct module dependency**

Move `github.com/prometheus/client_golang v1.23.2` from indirect to the direct `require` block, then run `go mod tidy` only if Go requires it.

- [ ] **Step 4: Run package tests**

Run: `go test ./internal/observability/http_metrics -count=1`

Expected: `ok   voice-platform/backend/internal/observability/http_metrics`.

### Task 3: Bind internal metrics and deny public routing

**Files:**
- Modify: `backend/cmd/api/main.go`
- Modify: `docker/Caddyfile`

- [ ] **Step 1: Mount the internal handler and middleware**

Create one recorder in `main`, register `GET /metrics` on the API mux, and order the server chain as:

```go
requestid.Middleware(recorder.Middleware(originMiddleware(mux)))
```

- [ ] **Step 2: Add explicit routes that preserve API paths and deny public metrics**

Use a literal `route` sequence so the API matcher does not rewrite `/api/v1/...`; add the public deny before the web fallback:

```caddyfile
route {
  @api path /api /api/*
  reverse_proxy @api api:8080

  @private_metrics path /metrics /metrics/*
  respond @private_metrics "Not Found" 404

  reverse_proxy web:80
}
```

The API container remains unported on the private Docker network, so internal collectors can request `http://api:8080/metrics`.

- [ ] **Step 3: Validate code and configuration**

Run:

```powershell
go test ./internal/observability/http_metrics ./cmd/api -count=1
go vet ./...
docker compose --env-file .env.example -f compose.yaml config --quiet
git diff --check -- backend/internal/observability/http_metrics backend/cmd/api/main.go backend/go.mod docker/Caddyfile
```

Expected: checks pass; public Caddy behavior is verified after a controlled deployment, while metric values for voice, SFU, disk and uploads remain separate observability leaves.
