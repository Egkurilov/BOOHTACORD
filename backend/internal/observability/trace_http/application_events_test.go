package tracehttp

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
)

func TestMiddlewareRecordsSafeApplicationEvents(t *testing.T) {
	tests := []struct {
		pattern string
		path    string
		status  int
		want    string
	}{
		{"POST /api/v1/channels/{channelID}/messages", "/api/v1/channels/private-id/messages", 201, "app.message.sent"},
		{"POST /api/v1/channels/{channelID}/messages", "/api/v1/channels/private-id/messages", 403, "app.message.sent.rejected"},
		{"POST /api/v1/channels/{channelID}/messages", "/api/v1/channels/private-id/messages", 500, "app.message.sent.failed"},
	}
	for _, test := range tests {
		t.Run(test.want+test.path, func(t *testing.T) {
			recorder := tracetest.NewSpanRecorder()
			provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(recorder))
			defer provider.Shutdown(t.Context())
			mux := http.NewServeMux()
			mux.HandleFunc(test.pattern, func(writer http.ResponseWriter, _ *http.Request) { writer.WriteHeader(test.status) })
			request := httptest.NewRequest(http.MethodPost, test.path+"?token=private-query", strings.NewReader("private-message"))
			Middleware(provider.Tracer("test"), mux, mux).ServeHTTP(httptest.NewRecorder(), request)
			spans := recorder.Ended()
			if len(spans) != 1 {
				t.Fatalf("spans=%d", len(spans))
			}
			events := spans[0].Events()
			if len(events) != 1 || events[0].Name != test.want || len(events[0].Attributes) != 0 {
				t.Fatalf("events=%+v, want one fixed event %q", events, test.want)
			}
			if strings.Contains(events[0].Name, "private") {
				t.Fatal("private value in event")
			}
		})
	}
}
