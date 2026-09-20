# Realtime Connection Observability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expose private aggregate WebSocket connection activity and `connection.ready` latency without leaking account, cookie, event or message data.

**Architecture:** The realtime handler accepts a narrow observer and reports open, ready duration and close only after WebSocket acceptance. `http_metrics` owns a no-label gauge, counter and histogram in its existing private registry. The API route injects the recorder, while Caddy continues denying public `/metrics`.

**Tech Stack:** Go 1.26, coder/websocket, Prometheus client, Caddy.

---

### Task 1: Add fixed private realtime collectors

**Files:**
- Modify: `backend/internal/observability/http_metrics/recorder.go`
- Create: `backend/internal/observability/http_metrics/realtime_connections.go`
- Modify: `backend/internal/observability/http_metrics/recorder_test.go`

- [x] **Step 1: Write a failing scrape test.**

```go
recorder.RealtimeConnectionOpened()
recorder.ObserveRealtimeConnectionReady(25 * time.Millisecond)
recorder.RealtimeConnectionClosed()
metrics := scrapeRecorder(t, recorder)
for _, name := range []string{
	"voice_platform_realtime_connections_active 0",
	"voice_platform_realtime_connections_total 1",
	"voice_platform_realtime_connection_ready_seconds_count 1",
} {
	if !strings.Contains(metrics, name) { t.Fatalf("metrics = %q", metrics) }
}
```

Require that the scrape contains no account UUID, cookie name, event payload or request path.

- [x] **Step 2: Confirm the test fails.**

Run: `go test ./internal/observability/http_metrics -run TestRecorderPublishesRealtimeConnectionMetrics -count=1`

Expected: FAIL because the realtime recorder methods are absent.

- [x] **Step 3: Register only no-label metrics.**

```go
active := prometheus.NewGauge(prometheus.GaugeOpts{Name: "voice_platform_realtime_connections_active", Help: "Accepted realtime WebSocket connections."})
total := prometheus.NewCounter(prometheus.CounterOpts{Name: "voice_platform_realtime_connections_total", Help: "Accepted realtime WebSocket connections."})
ready := prometheus.NewHistogram(prometheus.HistogramOpts{Name: "voice_platform_realtime_connection_ready_seconds", Help: "Time from WebSocket acceptance to connection.ready."})
```

`RealtimeConnectionOpened`, `ObserveRealtimeConnectionReady` and `RealtimeConnectionClosed` accept no identifier, error, event or payload. Keep the existing recorder within the 120-line source limit by moving realtime mechanics to `realtime_connections.go`.

- [x] **Step 4: Run the recorder package.**

Run: `go test ./internal/observability/http_metrics -count=1`

Expected: PASS.

### Task 2: Observe the authenticated WebSocket lifecycle

**Files:**
- Modify: `backend/internal/realtime/connect_session/http_handler.go`
- Modify: `backend/internal/realtime/connect_session/http_handler_test.go`
- Modify: `backend/cmd/api/realtime_routes.go`
- Modify: `backend/cmd/api/main.go`

- [x] **Step 1: Write a failing lifecycle-observer test.**

```go
observer := &fakeConnectionObserver{closed: make(chan struct{})}
handler := NewHandler(nil, 0, time.Now, nil, observer)
// Dial with a verified principal, read connection.ready, close it, then await observer.closed.
if observer.opened != 1 || observer.ready != 1 || observer.closedCount != 1 {
	t.Fatalf("observer = %#v", observer)
}
```

The fake observer stores only integer counts and a duration; it must not receive a principal, cookie or event payload.

- [x] **Step 2: Confirm the test fails.**

Run: `go test ./internal/realtime/connect_session -run TestHandlerObservesRealtimeLifecycle -count=1`

Expected: FAIL because `NewHandler` has no observer parameter.

- [x] **Step 3: Implement a narrow observer edge.**

```go
type ConnectionObserver interface {
	RealtimeConnectionOpened()
	ObserveRealtimeConnectionReady(time.Duration)
	RealtimeConnectionClosed()
}
```

After `websocket.Accept` succeeds, call `RealtimeConnectionOpened` and defer `RealtimeConnectionClosed`. Measure from that point through the successful `connection.ready` write; do not record a duration when ready could not be written. Pass the existing `httpmetrics.Recorder` through `configureRealtimeRoutes`.

- [x] **Step 4: Run realtime and API regressions.**

Run: `go test ./internal/realtime/connect_session ./cmd/api ./internal/observability/http_metrics -count=1`

Expected: PASS.

### Task 3: Record the live privacy boundary

**Files:**
- Modify: `docs/ARCHITECTURE_AND_DATA.md`
- Create: `evidence/observability-realtime-connections-2026-09-19-001.json`

- [x] **Step 1: Document the exact metrics.**

Add one sentence naming active, total and ready-duration metrics and stating that their labels are empty and they exclude account IDs, cookies, events, message data and channel IDs.

- [x] **Step 2: Write a truthful evidence record.**

```json
{
  "id": "observability-realtime-connections-2026-09-19-001",
  "kind": "private-observability",
  "status": "PASS_STATIC",
  "checks": { "no_label_metrics": "PASS", "public_metrics_route": "PASS_404", "production_connection_sample": "NOT_RUN" }
}
```

- [x] **Step 3: Validate the packet.**

Run: `Get-Content -Raw evidence/observability-realtime-connections-2026-09-19-001.json | ConvertFrom-Json | Out-Null; go test ./internal/realtime/connect_session ./cmd/api ./internal/observability/http_metrics -count=1; pwsh -NoProfile -File scripts/verify-contracts.ps1`

Expected: JSON parse and all focused checks PASS; a real production WebSocket sample remains unclaimed.

## Self-review

- **Spec coverage:** This implements the active/total/realtime-ready part of T-053 while keeping metrics private and low-cardinality.
- **Gaps intentionally not claimed:** It does not measure message delivery latency, voice participants, streams, reconnect, upload or disk state, and it does not satisfy hardware/media POC gates.
- **Type consistency:** `ConnectionObserver` has exactly the three methods supplied by `httpmetrics.Recorder`; the realtime route passes the one recorder already used by the API.
