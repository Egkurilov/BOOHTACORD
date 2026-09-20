# Upload Failure Metrics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish bounded, private counters for text-channel attachment upload failures without exposing request paths, account IDs, filenames, storage keys or raw errors.

**Architecture:** The upload HTTP handler maps each known failure branch to one fixed reason string and receives a narrow recorder interface. The Prometheus recorder accepts only those five reason values, normalizes all other input to `internal`, and publishes one counter vector. The route composition passes the existing private recorder into the handler.

**Tech Stack:** Go, `prometheus/client_golang`, `net/http`, repository-native Go tests.

---

### Task 1: Specify the handler and metric privacy contracts

**Files:**
- Modify: `backend/internal/storage/upload_text_attachment/api/http_handler_test.go`
- Create: `backend/internal/observability/http_metrics/upload_failures_test.go`
- Test: `backend/internal/storage/upload_text_attachment/api/http_handler_test.go`
- Test: `backend/internal/observability/http_metrics/upload_failures_test.go`

- [x] **Step 1: Add a failing table-driven handler test for fixed failure reasons.**

```go
for _, test := range []struct {
    name   string
    err    error
    reason string
}{
    {name: "too large", err: writeupload.ErrTooLarge, reason: "too_large"},
    {name: "storage", err: reserve.ErrInsufficientStorage, reason: "insufficient_storage"},
    {name: "target", err: authorize.ErrTargetUnavailable, reason: "target_unavailable"},
    {name: "internal", err: errors.New("private filename"), reason: "internal"},
} {
    t.Run(test.name, func(t *testing.T) {
        failures := &fakeFailureRecorder{}
        NewHandler(&fakeUploader{err: test.err}, failures).ServeHTTP(recorder, request)
        if failures.reasons[0] != test.reason { t.Fatalf("reason = %q", failures.reasons[0]) }
    })
}
```

- [x] **Step 2: Add a failing collector test that checks allowed labels and normalization.**

```go
recorder := New()
recorder.UploadFailed("too_large")
recorder.UploadFailed("/private/alice.png")
metrics := scrapeMetrics(t, recorder)
if !strings.Contains(metrics, `reason="too_large"`) || !strings.Contains(metrics, `reason="internal"`) {
    t.Fatalf("metrics = %q", metrics)
}
if strings.Contains(metrics, "alice.png") { t.Fatalf("metrics leaked input: %q", metrics) }
```

- [x] **Step 3: Run the focused tests and confirm compilation fails before the new recorder API exists.**

Run: `go test ./internal/storage/upload_text_attachment/api ./internal/observability/http_metrics -count=1`

Expected: failure because `NewHandler` lacks the failure recorder parameter or `Recorder.UploadFailed` is undefined.

### Task 2: Implement bounded failure classification and private collection

**Files:**
- Create: `backend/internal/observability/http_metrics/upload_failures.go`
- Modify: `backend/internal/observability/http_metrics/recorder.go`
- Modify: `backend/internal/storage/upload_text_attachment/api/http_handler.go`
- Modify: `backend/cmd/api/storage_routes.go`
- Test: `backend/internal/storage/upload_text_attachment/api/http_handler_test.go`
- Test: `backend/internal/observability/http_metrics/upload_failures_test.go`

- [x] **Step 1: Add the collector with a fixed `reason` vocabulary.**

```go
var uploadFailureReasons = map[string]struct{}{
    "invalid_multipart": {}, "too_large": {}, "insufficient_storage": {},
    "target_unavailable": {}, "internal": {},
}

func (collector *uploadFailures) Observe(reason string) {
    if _, ok := uploadFailureReasons[reason]; !ok { reason = "internal" }
    collector.total.WithLabelValues(reason).Inc()
}
```

- [x] **Step 2: Register `voice_platform_upload_failures_total` through `Recorder` and expose `UploadFailed(reason string)`.**

```go
uploadFailures := newUploadFailures()
registry.MustRegister(requests, duration, voiceSFURevocations, realtime.active, realtime.total, realtime.ready, uploadFailures.total)
return &Recorder{uploadFailures: uploadFailures, /* existing fields */}
```

- [x] **Step 3: Record each upload-handler failure before writing its existing HTTP response.**

```go
type FailureRecorder interface { UploadFailed(reason string) }

if err != nil || part.FormName() != "file" || part.FileName() == "" {
    failures.UploadFailed("invalid_multipart")
    writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Ожидался файл вложения")
    return
}
```

Use `too_large`, `insufficient_storage`, `target_unavailable`, and `internal` for the matching existing branches. Preserve every status, public error code and message.

- [x] **Step 4: Wire `metrics` into the handler construction.**

```go
mux.Handle("POST /api/v1/channels/{channelID}/attachments", sessionapi.Require(sessions)(limiter.Middleware(uploadapi.NewHandler(uploader, metrics))))
```

- [x] **Step 5: Run the focused tests and require success.**

Run: `go test ./internal/storage/upload_text_attachment/api ./internal/observability/http_metrics ./cmd/api -count=1`

Expected: PASS.

### Task 3: Validate the packet without disrupting live media

**Files:**
- Validate: `backend/internal/storage/upload_text_attachment/api/http_handler.go`
- Validate: `backend/internal/observability/http_metrics/upload_failures.go`
- Validate: `backend/cmd/api/storage_routes.go`

- [x] **Step 1: Format and run the repository-native checks.**

Run: `gofmt -w backend/internal/observability/http_metrics/upload_failures.go backend/internal/observability/http_metrics/upload_failures_test.go backend/internal/observability/http_metrics/recorder.go backend/internal/storage/upload_text_attachment/api/http_handler.go backend/internal/storage/upload_text_attachment/api/http_handler_test.go backend/cmd/api/storage_routes.go`, `go test ./... -count=1`, `go vet ./...`, and `powershell -ExecutionPolicy Bypass -File scripts/verify-contracts.ps1`.

Expected: every command succeeds.

- [x] **Step 2: Verify the metric is private and the packet has no whitespace errors.**

Run: `git diff --check -- backend/internal/observability/http_metrics backend/internal/storage/upload_text_attachment/api backend/cmd/api/storage_routes.go`.

Expected: no diff errors; public `/metrics` remains absent because the existing routing boundary is unchanged.

- [x] **Step 3: Preserve the active media session.**

Do not deploy or recreate production containers during the reported Windows/macOS call. A later rollout must use a pinned API image, keep `/metrics` private, and verify health plus a private scrape after the call ends.
