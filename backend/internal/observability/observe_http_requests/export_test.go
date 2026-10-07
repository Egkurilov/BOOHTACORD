package observehttprequests

import (
	"encoding/json"
	"github.com/prometheus/client_golang/prometheus"
	"go.opentelemetry.io/otel"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/metric/metricdata"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestRouteMetricsReachOTelWithoutPrivateValues(t *testing.T) {
	reader := sdkmetric.NewManualReader()
	provider := sdkmetric.NewMeterProvider(sdkmetric.WithReader(reader))
	old := otel.GetMeterProvider()
	otel.SetMeterProvider(provider)
	defer func() { otel.SetMeterProvider(old); provider.Shutdown(t.Context()) }()
	m := New(prometheus.NewRegistry())
	mux := http.NewServeMux()
	mux.HandleFunc("GET /items/{id}", func(http.ResponseWriter, *http.Request) {})
	m.Observe(httptest.NewRequest("GET", "/items/private?token=secret", nil), mux, 503, time.Millisecond)
	var data metricdata.ResourceMetrics
	if err := reader.Collect(t.Context(), &data); err != nil {
		t.Fatal(err)
	}
	encoded, _ := json.Marshal(data)
	out := string(encoded)
	for _, want := range []string{"boohtacord.incident.http.requests", "boohtacord.incident.http.duration", "/items/{id}"} {
		if !strings.Contains(out, want) {
			t.Fatal(out)
		}
	}
	for _, bad := range []string{"private", "secret"} {
		if strings.Contains(out, bad) {
			t.Fatal(out)
		}
	}
}
