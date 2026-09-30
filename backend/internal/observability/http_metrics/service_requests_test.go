package httpmetrics

import (
	"bytes"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestServiceRequestsDoNotCreateRequestMetricsOrLogs(t *testing.T) {
	recorder := New()
	var logs bytes.Buffer
	logger := slog.New(slog.NewJSONHandler(&logs, nil))
	handler := LoggingMiddleware(logger, recorder.Middleware(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusAccepted)
	})))
	for _, path := range []string{"/metrics", "/api/v1/health", "/api/v1/maintenance", "/api/v1/auth/session", "/api/v1/telemetry/traces", "/api/v1/voice/rosters/events"} {
		handler.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest(http.MethodPost, path, nil))
	}
	scrape := httptest.NewRecorder()
	recorder.Handler().ServeHTTP(scrape, httptest.NewRequest(http.MethodGet, "/metrics", nil))
	if strings.Contains(scrape.Body.String(), "voice_platform_api_requests_total") || logs.Len() != 0 {
		t.Fatalf("service traffic recorded: metrics=%q logs=%q", scrape.Body.String(), logs.String())
	}
}
