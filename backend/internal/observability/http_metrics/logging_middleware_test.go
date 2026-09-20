package httpmetrics

import (
	"bytes"
	"encoding/json"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"regexp"
	"strings"
	"testing"

	"voice-platform/backend/internal/security/request_id"
)

func TestLoggingMiddlewareRecordsOnlySafeCompletionFields(t *testing.T) {
	var output bytes.Buffer
	logger := slog.New(slog.NewJSONHandler(&output, nil))
	handler := requestid.Middleware(LoggingMiddleware(logger, http.HandlerFunc(func(writer http.ResponseWriter, _ *http.Request) {
		writer.WriteHeader(http.StatusCreated)
	})))
	request := httptest.NewRequest(http.MethodPost, "/api/v1/channels/secret-channel?token=query-secret", strings.NewReader("body-secret"))
	request.Header.Set("Cookie", "session=cookie-secret")
	request.Header.Set("X-Request-ID", "client-controlled")
	handler.ServeHTTP(httptest.NewRecorder(), request)

	var record map[string]any
	if err := json.Unmarshal(output.Bytes(), &record); err != nil {
		t.Fatal(err)
	}
	requestID, _ := record["request_id"].(string)
	if record["msg"] != "http.request.completed" || record["method"] != http.MethodPost || record["status"] != float64(http.StatusCreated) || record["duration_ms"] == nil || requestID == "client-controlled" || !regexp.MustCompile(`^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$`).MatchString(requestID) {
		t.Fatalf("record = %#v", record)
	}
	for _, secret := range []string{"secret-channel", "query-secret", "body-secret", "cookie-secret"} {
		if strings.Contains(output.String(), secret) {
			t.Fatalf("record leaked %q: %q", secret, output.String())
		}
	}
}

func TestLoggingMiddlewareSkipsMetricsScrapes(t *testing.T) {
	var output bytes.Buffer
	logger := slog.New(slog.NewJSONHandler(&output, nil))
	LoggingMiddleware(logger, http.HandlerFunc(func(writer http.ResponseWriter, _ *http.Request) {
		writer.WriteHeader(http.StatusNoContent)
	})).ServeHTTP(httptest.NewRecorder(), httptest.NewRequest(http.MethodGet, "/metrics", nil))
	if output.Len() != 0 {
		t.Fatalf("metrics scrape was logged: %q", output.String())
	}
}
