package tracehttp

import (
	"net/http"
	"net/http/httptest"
	"testing"

	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
)

func TestWebSocketHandshakeContinuesW3CTraceparent(t *testing.T) {
	recorder := tracetest.NewSpanRecorder()
	provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(recorder))
	defer provider.Shutdown(t.Context())
	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/v1/realtime", func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusSwitchingProtocols) })
	request := httptest.NewRequest(http.MethodGet, "/api/v1/realtime?traceparent=00-11111111111111111111111111111111-2222222222222222-01&tracestate=vendor%3Dstate", nil)
	request.Header.Set("Upgrade", "websocket")
	Middleware(provider.Tracer("test"), mux, mux).ServeHTTP(httptest.NewRecorder(), request)
	spans := recorder.Ended()
	if len(spans) != 1 || spans[0].SpanContext().TraceID().String() != "11111111111111111111111111111111" || spans[0].Parent().SpanID().String() != "2222222222222222" {
		t.Fatalf("W3C parent was not continued: %#v", spans)
	}
	if spans[0].Parent().TraceState().Get("vendor") != "state" {
		t.Fatalf("W3C tracestate was not continued: %s", spans[0].Parent().TraceState())
	}
}
