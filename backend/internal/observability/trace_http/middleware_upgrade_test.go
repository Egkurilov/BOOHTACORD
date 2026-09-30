package tracehttp

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/coder/websocket"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
)

func TestMiddlewarePreservesWebSocketUpgrade(t *testing.T) {
	recorder := tracetest.NewSpanRecorder()
	provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(recorder))
	defer provider.Shutdown(t.Context())
	accepted := make(chan error, 1)
	mux := http.NewServeMux()
	mux.HandleFunc("GET /ws", func(writer http.ResponseWriter, request *http.Request) {
		connection, err := websocket.Accept(writer, request, nil)
		if err == nil {
			connection.CloseNow()
		}
		accepted <- err
	})
	server := httptest.NewServer(Middleware(provider.Tracer("test"), mux, mux))
	defer server.Close()
	connection, _, err := websocket.Dial(context.Background(), "ws"+strings.TrimPrefix(server.URL, "http")+"/ws", nil)
	if err != nil {
		t.Fatal(err)
	}
	connection.CloseNow()
	if err := <-accepted; err != nil {
		t.Fatal(err)
	}
	deadline := time.Now().Add(time.Second)
	for len(recorder.Ended()) == 0 && time.Now().Before(deadline) {
		time.Sleep(time.Millisecond)
	}
	if len(recorder.Ended()) != 1 {
		t.Fatal("WebSocket handshake was not traced")
	}
}

func TestMiddlewareSkipsScrapesAndBoundsUnknownRoutes(t *testing.T) {
	recorder := tracetest.NewSpanRecorder()
	provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(recorder))
	defer provider.Shutdown(t.Context())
	mux := http.NewServeMux()
	mux.HandleFunc("GET /metrics", func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusOK) })
	mux.HandleFunc("GET /api/v1/health", func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusOK) })
	handler := Middleware(provider.Tracer("test"), mux, mux)
	for _, path := range []string{"/metrics", "/api/v1/health", "/secret-path"} {
		handler.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest(http.MethodGet, path, nil))
	}
	spans := recorder.Ended()
	if len(spans) != 1 || strings.Contains(spans[0].Name(), "secret-path") {
		t.Fatalf("unexpected spans: %+v", spans)
	}
}
