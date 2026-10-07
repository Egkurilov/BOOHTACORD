package httpmetrics

import (
	"bytes"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	tracehttp "voice-platform/backend/internal/observability/trace_http"
	requestid "voice-platform/backend/internal/security/request_id"
)

func TestPanicCompletionKeepsSafeRequestCorrelation(t *testing.T) {
	var logs bytes.Buffer
	logger := slog.New(slog.NewJSONHandler(&logs, nil))
	m := New()
	mux := http.NewServeMux()
	mux.HandleFunc("GET /items/{id}", func(http.ResponseWriter, *http.Request) { panic("private panic token") })
	spans := tracetest.NewSpanRecorder()
	provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(spans))
	defer provider.Shutdown(t.Context())
	h := requestid.Middleware(LoggingMiddleware(logger, m.Middleware(tracehttp.Middleware(provider.Tracer("test"), mux, mux), mux)))
	response := httptest.NewRecorder()
	r := httptest.NewRequest("GET", "/items/private-id?token=secret", nil)
	r.Header.Set("Cookie", "cookie-secret")
	r.Header.Set("X-Request-ID", "client-secret")
	func() {
		defer func() {
			if recover() == nil {
				t.Fatal("panic swallowed")
			}
		}()
		h.ServeHTTP(response, r)
	}()
	id := response.Header().Get("X-Request-ID")
	if id == "" || !strings.Contains(logs.String(), id) || !strings.Contains(logs.String(), `"status":500`) {
		t.Fatal("safe completion correlation missing")
	}
	ended := spans.Ended()
	if len(ended) != 1 {
		t.Fatal("panic span absent")
	}
	found := false
	for _, a := range ended[0].Attributes() {
		if a.Key == "request_id" && a.Value.AsString() == id {
			found = true
		}
	}
	if !found {
		t.Fatal("request ID differs")
	}
	if !strings.Contains(scrapeMetrics(m), `route="/items/{id}",status="500"} 1`) {
		t.Fatal("panic metric absent")
	}
	for _, bad := range []string{"private panic token", "private-id", "cookie-secret", "client-secret", "token=secret"} {
		if strings.Contains(logs.String(), bad) {
			t.Fatal("private panic/input logged")
		}
	}
}
