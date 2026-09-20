# SFU Revocation Observability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expose private, low-cardinality counts for completed, pending and failed durable SFU-revocation dispatches without recording identities, media credentials or raw errors.

**Architecture:** `dispatch_voice_sfu_revocation` retains its bounded deadline and returns its existing aggregate `Result` to the API worker. The worker maps aggregate counts to fixed outcomes, and the existing private Prometheus recorder owns the counter. Caddy continues to return `404` for public `/metrics`.

**Tech Stack:** Go 1.26, Prometheus client, `log/slog`, Docker Compose/Caddy.

---

### Task 1: Preserve the bounded dispatch result

**Files:**
- Modify: `backend/internal/media/dispatch_voice_sfu_revocation/worker.go`
- Modify: `backend/internal/media/dispatch_voice_sfu_revocation/worker_test.go`

- [x] **Step 1: Write a failing result-preservation test.**

```go
func TestDispatchPendingReturnsBoundedDispatchResult(t *testing.T) {
	dispatcher := &fakeDispatcher{result: Result{Confirmed: 2, Pending: 1}}
	result, err := DispatchPending(context.Background(), dispatcher)
	if err != nil || result != dispatcher.result || dispatcher.limit != 100 || !dispatcher.hasDeadline {
		t.Fatalf("result = %#v, error = %v, dispatcher = %#v", result, err, dispatcher)
	}
}
```

- [x] **Step 2: Confirm it fails.**

Run: `go test ./internal/media/dispatch_voice_sfu_revocation -run TestDispatchPendingReturnsBoundedDispatchResult -count=1`

Expected: FAIL because `DispatchPending` returns only an error.

- [x] **Step 3: Return the existing aggregate, still using the fixed timeout and batch.**

```go
func DispatchPending(parent context.Context, dispatcher Dispatcher) (Result, error) {
	bounded, cancel := context.WithTimeout(parent, dispatchTimeout)
	defer cancel()
	return dispatcher.Dispatch(bounded, dispatchBatchLimit)
}
```

The API boundary receives no individual lease, channel or account value.

- [x] **Step 4: Run the package.**

Run: `go test ./internal/media/dispatch_voice_sfu_revocation -count=1`

Expected: PASS.

- [x] **Step 5: Preserve the source-state boundary.**

Run: `git status --short -- backend/internal/media/dispatch_voice_sfu_revocation`

Expected: inspect only the exact files; do not stage or commit shared-worktree changes.

### Task 2: Add a fixed-outcome private counter

**Files:**
- Modify: `backend/internal/observability/http_metrics/recorder.go`
- Create: `backend/internal/observability/http_metrics/sfu_revocation.go`
- Modify: `backend/internal/observability/http_metrics/recorder_test.go`

- [x] **Step 1: Write a failing private-scrape test.**

```go
recorder.ObserveVoiceSFURevocation(2, 1, true)
metrics := scrapeRecorder(t, recorder)
for _, line := range []string{
	`voice_platform_voice_sfu_revocations_total{outcome="confirmed"} 2`,
	`voice_platform_voice_sfu_revocations_total{outcome="pending"} 1`,
	`voice_platform_voice_sfu_revocations_total{outcome="failed"} 1`,
} {
	if !strings.Contains(metrics, line) { t.Fatalf("metrics = %q", metrics) }
}
```

Also require the scrape not to contain representative lease or channel UUIDs.

- [x] **Step 2: Confirm it fails.**

Run: `go test ./internal/observability/http_metrics -run TestRecorderPublishesAggregatedSFURevocationMetrics -count=1`

Expected: FAIL because `ObserveVoiceSFURevocation` is absent.

- [x] **Step 3: Register and expose only three fixed outcomes.**

```go
voiceSFURevocations := prometheus.NewCounterVec(prometheus.CounterOpts{
	Name: "voice_platform_voice_sfu_revocations_total",
	Help: "Durable SFU revocation dispatch outcomes.",
}, []string{"outcome"})
registry.MustRegister(requests, duration, voiceSFURevocations)
```

`ObserveVoiceSFURevocation(confirmed, pending int, failed bool)` increments positive confirmed/pending counts and one failed event. It accepts no error, user, channel, lease, route, token or message argument.

- [x] **Step 4: Run the recorder package.**

Run: `go test ./internal/observability/http_metrics -count=1`

Expected: PASS.

- [x] **Step 5: Preserve the source-state boundary.**

Run: `git status --short -- backend/internal/observability/http_metrics`

Expected: inspect only exact files; do not stage or commit shared-worktree changes.

### Task 3: Record worker outcomes without sensitive logs

**Files:**
- Modify: `backend/cmd/api/voice_sfu_revocation_worker.go`
- Create: `backend/cmd/api/voice_sfu_revocation_worker_test.go`
- Modify: `backend/cmd/api/main.go`

- [x] **Step 1: Write failing worker tests.**

```go
func TestAttemptRecordsAggregateDispatchOutcome(t *testing.T) {
	observer := &fakeVoiceSFUObserver{}
	attemptVoiceSFURevocationDispatch(context.Background(), dispatcherFunc(func(context.Context, int) (dispatchvoicesfurevocation.Result, error) {
		return dispatchvoicesfurevocation.Result{Confirmed: 2, Pending: 1}, dispatchvoicesfurevocation.ErrPending
	}), observer)
	if observer.confirmed != 2 || observer.pending != 1 || observer.failed { t.Fatalf("observer = %#v", observer) }
}
```

Add a storage-failure test that records only `failed: true`; no test observer method accepts a dynamic error string.

- [x] **Step 2: Confirm it fails.**

Run: `go test ./cmd/api -run TestAttemptRecordsAggregateDispatchOutcome -count=1`

Expected: FAIL because the worker has no observer edge.

- [x] **Step 3: Wire a narrow observer and fixed classification.**

```go
type voiceSFURevocationObserver interface {
	ObserveVoiceSFURevocation(confirmed, pending int, failed bool)
}

result, err := dispatchvoicesfurevocation.DispatchPending(context, dispatcher)
observer.ObserveVoiceSFURevocation(result.Confirmed, result.Pending, err != nil && !errors.Is(err, dispatchvoicesfurevocation.ErrPending))
```

Keep the warning free of IDs, tokens, messages and raw errors. Pass the existing `httpmetrics.Recorder` from `main` when starting the worker.

- [x] **Step 4: Run the focused regression set.**

Run: `go test ./cmd/api ./internal/media/dispatch_voice_sfu_revocation ./internal/observability/http_metrics -count=1`

Expected: PASS.

- [x] **Step 5: Preserve the source-state boundary.**

Run: `git status --short -- backend/cmd/api`

Expected: inspect only exact files; do not stage or commit shared-worktree changes.

### Task 4: Record the privacy and evidence boundary

**Files:**
- Modify: `docs/ARCHITECTURE_AND_DATA.md`
- Create: `evidence/observability-sfu-revocation-2026-09-19-001.json`

- [x] **Step 1: Document the metric boundary.**

Add one sentence: `/metrics` remains private and this counter has only `confirmed`, `pending` and `failed` outcomes; it excludes lease, account, channel, error and media-token values.

- [x] **Step 2: Add a truthful static record.**

```json
{
  "id": "observability-sfu-revocation-2026-09-19-001",
  "kind": "private-observability",
  "status": "PASS_STATIC",
  "checks": { "fixed_labels": "PASS", "public_metrics_route": "PASS_404", "production_scrape": "NOT_RUN" }
}
```

- [x] **Step 3: Validate the complete packet.**

Run: `Get-Content -Raw evidence/observability-sfu-revocation-2026-09-19-001.json | ConvertFrom-Json | Out-Null; go test ./cmd/api ./internal/media/dispatch_voice_sfu_revocation ./internal/observability/http_metrics -count=1; pwsh -NoProfile -File scripts/verify-contracts.ps1`

Expected: JSON parse and native checks PASS; production scrape stays explicitly unclaimed.

## Self-review

- **Spec coverage:** Tasks 1–3 implement one required private SFU-error/outcome observability leaf and retain the existing Caddy deny rule. Task 4 documents its privacy and evidence scope.
- **Gaps intentionally not claimed:** Participants, streams, reconnect, upload, disk and WebSocket latency remain independent T-053 leaves. This plan does not establish POC-01, POC-02, POC-03 or capacity.
- **Type consistency:** `DispatchPending` returns `Result`; the API worker maps it to `ObserveVoiceSFURevocation(confirmed, pending, failed)`; the recorder creates only fixed outcome labels.
