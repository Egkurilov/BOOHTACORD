package httpmetrics

import (
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	tracehttp "voice-platform/backend/internal/observability/trace_http"
)

func TestCapturedStatusMatchesFinalWireResponse(t *testing.T) {
	for _, mode := range []string{"continue", "early-hints", "flush"} {
		for _, traceOutside := range []bool{false, true} {
			t.Run(mode+map[bool]string{true: "-trace", false: "-metrics"}[traceOutside], func(t *testing.T) {
				m := New()
				mux := http.NewServeMux()
				spans := tracetest.NewSpanRecorder()
				provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(spans))
				defer provider.Shutdown(t.Context())
				mux.HandleFunc("GET /status", func(w http.ResponseWriter, r *http.Request) {
					switch mode {
					case "continue":
						w.WriteHeader(100)
						w.WriteHeader(200)
					case "early-hints":
						w.WriteHeader(103)
						w.WriteHeader(200)
					case "flush":
						if err := http.NewResponseController(w).Flush(); err != nil {
							t.Error(err)
						}
						w.WriteHeader(500)
					}
					_, _ = w.Write([]byte("ok"))
				})
				var h http.Handler = m.Middleware(tracehttp.Middleware(provider.Tracer("test"), mux, mux), mux)
				if traceOutside {
					h = tracehttp.Middleware(provider.Tracer("test"), mux, m.Middleware(mux, mux))
				}
				server := httptest.NewServer(h)
				defer server.Close()
				response, err := http.Get(server.URL + "/status")
				if err != nil {
					t.Fatal(err)
				}
				_, err = io.ReadAll(response.Body)
				response.Body.Close()
				if err != nil || response.StatusCode != 200 {
					t.Fatalf("wire status=%d error=%v", response.StatusCode, err)
				}
				if !strings.Contains(scrapeMetrics(m), `route="/status",status="200"} 1`) {
					t.Fatal("metrics differ from wire status")
				}
				ended := spans.Ended()
				if len(ended) != 1 {
					t.Fatal("no completed span")
				}
				found := false
				for _, a := range ended[0].Attributes() {
					if a.Key == "http.response.status_code" && a.Value.AsInt64() == 200 {
						found = true
					}
				}
				if !found {
					t.Fatal("trace differs from wire status")
				}
			})
		}
	}
}
