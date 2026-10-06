package connectsession

import (
	"context"
	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
	"go.opentelemetry.io/otel"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"
	authenticatesession "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestHandshakeTraceEndsWhileSocketStillOpen(t *testing.T) {
	recorder := tracetest.NewSpanRecorder()
	provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(recorder))
	old := otel.GetTracerProvider()
	otel.SetTracerProvider(provider)
	t.Cleanup(func() { otel.SetTracerProvider(old) })
	closed := atomic.Bool{}
	handler := NewHandler(nil, 0, time.Now, nil, nil)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer closed.Store(true)
		handler.ServeHTTP(w, r.WithContext(sessionapi.WithPrincipal(r.Context(), authenticatesession.Principal{AccountID: "synthetic"})))
	}))
	defer server.Close()
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	conn, _, err := websocket.Dial(ctx, "ws"+strings.TrimPrefix(server.URL, "http"), &websocket.DialOptions{HTTPHeader: http.Header{"Origin": {server.URL}}})
	if err != nil {
		t.Fatal(err)
	}
	defer conn.CloseNow()
	var event Event
	if err := wsjson.Read(ctx, conn, &event); err != nil || event.Kind != "connection.ready" {
		t.Fatalf("ready=%s error=%v", event.Kind, err)
	}
	deadline := time.Now().Add(time.Second)
	for len(recorder.Ended()) == 0 && time.Now().Before(deadline) {
		time.Sleep(time.Millisecond)
	}
	spans := recorder.Ended()
	if len(spans) != 1 || spans[0].Name() != "realtime.connect.ready" || closed.Load() {
		t.Fatal("handshake waited for stream close")
	}
}
