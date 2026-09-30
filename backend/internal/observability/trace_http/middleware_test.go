package tracehttp

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"go.opentelemetry.io/otel"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/metric/metricdata"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
)

func TestMiddlewareRecordsSafeRouteAndStatus(t *testing.T) {
	recorder := tracetest.NewSpanRecorder()
	provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(recorder))
	defer provider.Shutdown(t.Context())
	mux := http.NewServeMux()
	mux.HandleFunc("POST /api/v1/messages/{messageID}", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusCreated)
	})
	request := httptest.NewRequest(http.MethodPost, "/api/v1/messages/private-id?token=query-secret", strings.NewReader("body-secret"))
	request.Header.Set("Cookie", "session=cookie-secret")
	request.Header.Set("traceparent", "00-11111111111111111111111111111111-2222222222222222-01")
	Middleware(provider.Tracer("test"), mux, mux).ServeHTTP(httptest.NewRecorder(), request)
	spans := recorder.Ended()
	if len(spans) != 1 || spans[0].Name() != "POST /api/v1/messages/{messageID}" || !spans[0].Parent().IsValid() {
		if len(spans) == 0 {
			t.Fatal("no spans recorded")
		}
		t.Fatalf("span count=%d name=%q parent_valid=%t", len(spans), spans[0].Name(), spans[0].Parent().IsValid())
	}
	if spans[0].SpanContext().TraceID().String() != "11111111111111111111111111111111" || spans[0].Parent().SpanID().String() != "2222222222222222" {
		t.Fatalf("W3C trace context was not continued: trace=%s parent=%s", spans[0].SpanContext().TraceID(), spans[0].Parent().SpanID())
	}
	encoded, err := json.Marshal(spans[0].Attributes())
	if err != nil {
		t.Fatal(err)
	}
	attributes := string(encoded)
	if !strings.Contains(attributes, "http.response.status_code") || !strings.Contains(attributes, "201") {
		t.Fatalf("missing status: %s", attributes)
	}
	for _, private := range []string{"private-id", "query-secret", "body-secret", "cookie-secret"} {
		if strings.Contains(attributes, private) {
			t.Fatalf("span attributes leaked %q", private)
		}
	}
}

func TestMiddlewareRecordsLowCardinalityMetrics(t *testing.T) {
	previous := otel.GetMeterProvider()
	reader := sdkmetric.NewManualReader()
	provider := sdkmetric.NewMeterProvider(sdkmetric.WithReader(reader))
	otel.SetMeterProvider(provider)
	defer func() { otel.SetMeterProvider(previous); _ = provider.Shutdown(t.Context()) }()
	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/v1/messages/{messageID}", func(writer http.ResponseWriter, _ *http.Request) {
		writer.WriteHeader(http.StatusNoContent)
	})
	request := httptest.NewRequest(http.MethodGet, "/api/v1/messages/private-id?secret=query-secret", nil)
	request.Header.Set("Cookie", "session=cookie-secret")
	Middleware(otel.Tracer("test"), mux, mux).ServeHTTP(httptest.NewRecorder(), request)
	var metrics metricdata.ResourceMetrics
	if err := reader.Collect(t.Context(), &metrics); err != nil {
		t.Fatal(err)
	}
	encoded, err := json.Marshal(metrics)
	if err != nil {
		t.Fatal(err)
	}
	output := string(encoded)
	if !strings.Contains(output, "boohtacord.http.server.requests") || !strings.Contains(output, "boohtacord.http.server.duration") {
		t.Fatalf("request metrics missing: %s", output)
	}
	if !strings.Contains(output, `"Bounds":[0.005,0.01,0.025,0.05`) {
		t.Fatalf("HTTP duration buckets do not resolve subsecond latency: %s", output)
	}
	for _, private := range []string{"private-id", "query-secret", "cookie-secret"} {
		if strings.Contains(output, private) {
			t.Fatalf("metrics leaked %q", private)
		}
	}
}

func TestMiddlewareSkipsServiceTraffic(t *testing.T) {
	recorder := tracetest.NewSpanRecorder()
	provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(recorder))
	defer provider.Shutdown(t.Context())
	mux := http.NewServeMux()
	mux.HandleFunc("POST /api/v1/telemetry/traces", func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusAccepted) })
	response := httptest.NewRecorder()
	Middleware(provider.Tracer("test"), mux, mux).ServeHTTP(response, httptest.NewRequest(http.MethodPost, "/api/v1/telemetry/traces", nil))
	if response.Code != http.StatusAccepted || len(recorder.Ended()) != 0 {
		t.Fatalf("telemetry relay status=%d spans=%d", response.Code, len(recorder.Ended()))
	}
}
