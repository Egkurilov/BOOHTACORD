package httpmetrics

import (
	"bufio"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	tracehttp "voice-platform/backend/internal/observability/trace_http"
)

type countedTransport struct {
	*httptest.ResponseRecorder
	flushes, hijacks int
}

func (w *countedTransport) Flush() { w.flushes++ }
func (w *countedTransport) Hijack() (net.Conn, *bufio.ReadWriter, error) {
	w.hijacks++
	return nil, nil, nil
}
func TestCombinedTraceAndMetricsPreserveUpgradeTransport(t *testing.T) {
	for _, traceOutside := range []bool{false, true} {
		t.Run(map[bool]string{false: "metrics-outside", true: "trace-outside"}[traceOutside], func(t *testing.T) {
			spans := tracetest.NewSpanRecorder()
			provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(spans))
			defer provider.Shutdown(t.Context())
			m := New()
			mux := http.NewServeMux()
			mux.HandleFunc("GET /ws", func(w http.ResponseWriter, r *http.Request) {
				w.WriteHeader(101)
				if err := http.NewResponseController(w).Flush(); err != nil {
					t.Fatal(err)
				}
				if _, _, err := http.NewResponseController(w).Hijack(); err != nil {
					t.Fatal(err)
				}
			})
			var h http.Handler = m.Middleware(tracehttp.Middleware(provider.Tracer("test"), mux, mux), mux)
			if traceOutside {
				h = tracehttp.Middleware(provider.Tracer("test"), mux, m.Middleware(mux, mux))
			}
			writer := &countedTransport{ResponseRecorder: httptest.NewRecorder()}
			h.ServeHTTP(writer, httptest.NewRequest("GET", "/ws", nil))
			if writer.flushes != 1 || writer.hijacks != 1 {
				t.Fatalf("flushes=%d hijacks=%d", writer.flushes, writer.hijacks)
			}
			if !strings.Contains(scrapeMetrics(m), `route="/ws",status="101"} 1`) {
				t.Fatal("upgrade status absent")
			}
			ended := spans.Ended()
			if len(ended) != 1 {
				t.Fatal("upgrade span absent")
			}
			found := false
			for _, a := range ended[0].Attributes() {
				if a.Key == "http.response.status_code" && a.Value.AsInt64() == 101 {
					found = true
				}
			}
			if !found {
				t.Fatal("upgrade trace status absent")
			}
		})
	}
}
