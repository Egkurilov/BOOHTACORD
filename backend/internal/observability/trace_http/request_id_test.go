package tracehttp

import (
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
	"net/http"
	"net/http/httptest"
	"testing"
	requestid "voice-platform/backend/internal/security/request_id"
)

func TestHTTPSpanUsesOnlyServerRequestID(t *testing.T) {
	recorder := tracetest.NewSpanRecorder()
	provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(recorder))
	defer provider.Shutdown(t.Context())
	mux := http.NewServeMux()
	mux.HandleFunc("GET /items/{id}", func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(204) })
	r := httptest.NewRequest("GET", "/items/private", nil)
	r.Header.Set("X-Request-ID", "client-secret")
	w := httptest.NewRecorder()
	requestid.Middleware(Middleware(provider.Tracer("test"), mux, mux)).ServeHTTP(w, r)
	found := false
	for _, a := range recorder.Ended()[0].Attributes() {
		if a.Key == "request_id" {
			found = true
			if a.Value.AsString() != w.Header().Get("X-Request-ID") || a.Value.AsString() == "client-secret" {
				t.Fatal("wrong correlation")
			}
		}
	}
	if !found {
		t.Fatal("request ID absent")
	}
}
