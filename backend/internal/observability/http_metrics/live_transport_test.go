package httpmetrics

import (
	"context"
	"github.com/coder/websocket"
	"go.opentelemetry.io/otel"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
	tracehttp "voice-platform/backend/internal/observability/trace_http"
)

func TestCombinedMiddlewareServesRealWebSocketAndFlushesOpenSSE(t *testing.T) {
	m := New()
	mux := http.NewServeMux()
	upgrade := make(chan error, 1)
	done := make(chan struct{})
	mux.HandleFunc("GET /ws", func(w http.ResponseWriter, r *http.Request) {
		conn, err := websocket.Accept(w, r, nil)
		if err == nil {
			conn.CloseNow()
		}
		upgrade <- err
	})
	mux.HandleFunc("GET /events", func(w http.ResponseWriter, r *http.Request) {
		defer close(done)
		w.Header().Set("Content-Type", "text/event-stream")
		_, _ = w.Write([]byte("data: ready\n\n"))
		if err := http.NewResponseController(w).Flush(); err != nil {
			t.Error(err)
		}
		<-r.Context().Done()
	})
	server := httptest.NewServer(m.Middleware(tracehttp.Middleware(otel.Tracer("test"), mux, mux), mux))
	defer server.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	conn, _, err := websocket.Dial(ctx, "ws"+strings.TrimPrefix(server.URL, "http")+"/ws", nil)
	if err != nil {
		t.Fatal(err)
	}
	conn.CloseNow()
	if err := <-upgrade; err != nil {
		t.Fatal(err)
	}
	request, _ := http.NewRequestWithContext(ctx, "GET", server.URL+"/events", nil)
	response, err := http.DefaultClient.Do(request)
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	body := make([]byte, len("data: ready\n\n"))
	if _, err := io.ReadFull(response.Body, body); err != nil || string(body) != "data: ready\n\n" {
		t.Fatalf("SSE flush=%q err=%v", body, err)
	}
	select {
	case <-done:
		t.Fatal("SSE closed before cancellation")
	default:
	}
	cancel()
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("stream did not stop")
	}
}
