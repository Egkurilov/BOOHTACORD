# Structured Request Logs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Emit bounded JSON completion logs for API requests with the server-generated request ID and no user-controlled request data.

**Architecture:** A middleware in the existing HTTP observability package reuses the response-writer compatibility adapter to log one completion record after each non-metrics request. The API process configures the default `slog` handler as JSON before startup and places the logger inside request-ID middleware so every record has a server-generated ID. The log schema is fixed to event, request ID, method, status and duration in milliseconds.

**Tech Stack:** Go standard library `log/slog`, `net/http`, repository-native Go tests.

---

### Task 1: Specify safe structured completion records

**Files:**
- Create: `backend/internal/observability/http_metrics/logging_middleware_test.go`
- Test: `backend/internal/observability/http_metrics/logging_middleware_test.go`

- [x] **Step 1: Add a failing JSON-record test.**

```go
logger := slog.New(slog.NewJSONHandler(&output, nil))
handler := requestid.Middleware(LoggingMiddleware(logger, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
    w.WriteHeader(http.StatusCreated)
})))
request := httptest.NewRequest(http.MethodPost, "/api/v1/channels/secret-channel?token=query-secret", strings.NewReader("body-secret"))
request.Header.Set("Cookie", "session=cookie-secret")
handler.ServeHTTP(httptest.NewRecorder(), request)
```

Assert a single JSON record has `msg="http.request.completed"`, a UUID `request_id`, `method="POST"`, `status=201`, and non-negative `duration_ms`. Assert the JSON omits `secret-channel`, `query-secret`, `body-secret`, and `cookie-secret`.

- [x] **Step 2: Add a failing metrics-route test.**

```go
LoggingMiddleware(logger, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
    w.WriteHeader(http.StatusNoContent)
})).ServeHTTP(httptest.NewRecorder(), httptest.NewRequest(http.MethodGet, "/metrics", nil))
if output.Len() != 0 { t.Fatalf("metrics scrape was logged: %q", output.String()) }
```

- [x] **Step 3: Run the package test before implementation.**

Run: `go test ./internal/observability/http_metrics -count=1`

Expected: failure because `LoggingMiddleware` is undefined.

### Task 2: Implement and compose structured logging

**Files:**
- Create: `backend/internal/observability/http_metrics/logging_middleware.go`
- Create: `backend/cmd/api/logging.go`
- Modify: `backend/cmd/api/main.go:47-101`
- Test: `backend/internal/observability/http_metrics/logging_middleware_test.go`

- [x] **Step 1: Add the completion middleware using the existing response writer adapter.**

```go
func LoggingMiddleware(logger *slog.Logger, next http.Handler) http.Handler {
    return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
        if request.URL.Path == "/metrics" { next.ServeHTTP(writer, request); return }
        started, captured := time.Now(), &responseWriter{ResponseWriter: writer}
        next.ServeHTTP(captured, request)
        logger.Info("http.request.completed",
            "request_id", requestid.From(request.Context()),
            "method", request.Method,
            "status", captured.statusCode(),
            "duration_ms", time.Since(started).Milliseconds(),
        )
    })
}
```

- [x] **Step 2: Configure a process-wide JSON slog handler without adding request fields at call sites.**

```go
func configureLogging() {
    slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))
}

func apiAddress() string {
    if address := os.Getenv("API_ADDR"); address != "" { return address }
    return ":8080"
}
```

- [x] **Step 3: Apply middleware in the safe order.**

```go
configureLogging()
server.Handler = requestid.Middleware(httpmetrics.LoggingMiddleware(slog.Default(), metrics.Middleware(configuration.originMiddleware(mux))))
```

Keep request ID outermost, retain API metrics behavior, and do not log URL paths, query strings, headers, bodies, sessions, tokens, account IDs, channel IDs, attachment IDs, filenames or errors.

- [x] **Step 4: Run the focused package and API tests.**

Run: `go test ./internal/observability/http_metrics ./cmd/api -count=1`

Expected: PASS.

### Task 3: Validate source and preserve current media

**Files:**
- Validate: `backend/internal/observability/http_metrics/logging_middleware.go`
- Validate: `backend/cmd/api/logging.go`
- Validate: `backend/cmd/api/main.go`

- [x] **Step 1: Run `gofmt`, `go test ./... -count=1`, `go vet ./...`, and `powershell -ExecutionPolicy Bypass -File scripts/verify-contracts.ps1`.**

Expected: each command succeeds.

- [x] **Step 2: Run `git diff --check` for the packet and inspect the changed file line counts.**

Expected: no whitespace errors and no production file exceeds 120 lines.

- [x] **Step 3: Do not deploy during the reported Windows/macOS media session.**

The later rollout must build a pinned API image, retain private `/metrics`, and inspect JSON logs without copying request data or raw media diagnostics into the repository.
