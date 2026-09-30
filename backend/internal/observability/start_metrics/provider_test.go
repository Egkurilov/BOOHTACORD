package startmetrics

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"go.opentelemetry.io/otel"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
)

func TestStartWithoutEndpointLeavesMetricsUnchanged(t *testing.T) {
	t.Setenv("OTEL_EXPORTER_OTLP_ENDPOINT", "")
	t.Setenv("OTEL_EXPORTER_OTLP_METRICS_ENDPOINT", "")
	before := otel.GetMeterProvider()
	shutdown, err := Start(context.Background())
	if err != nil || shutdown == nil || otel.GetMeterProvider() != before {
		t.Fatalf("disabled metrics changed provider: %v", err)
	}
	if err := shutdown(context.Background()); err != nil {
		t.Fatal(err)
	}
}

func TestStartExportsMetricToConfiguredEndpoint(t *testing.T) {
	type export struct {
		authorization, contentType string
		bytes                      int
	}
	received := make(chan export, 2)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		received <- export{r.Header.Get("Authorization"), r.Header.Get("Content-Type"), len(body)}
		w.WriteHeader(http.StatusOK)
	}))
	defer server.Close()
	t.Setenv("OTEL_EXPORTER_OTLP_ENDPOINT", "")
	t.Setenv("OTEL_EXPORTER_OTLP_METRICS_ENDPOINT", server.URL)
	t.Setenv("OTEL_EXPORTER_OTLP_PROTOCOL", "http/protobuf")
	t.Setenv("OTEL_INGEST_AUTH", "Bearer test-metric")
	oldProvider := otel.GetMeterProvider()
	t.Cleanup(func() { otel.SetMeterProvider(oldProvider) })

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	shutdown, err := Start(ctx)
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = shutdown(ctx) }()
	provider, ok := otel.GetMeterProvider().(*sdkmetric.MeterProvider)
	if !ok {
		t.Fatal("configured metric provider is not recording")
	}
	counter, err := provider.Meter("test/export").Int64Counter("test.counter")
	if err != nil {
		t.Fatal(err)
	}
	counter.Add(ctx, 1)
	if err := provider.ForceFlush(ctx); err != nil {
		t.Fatal(err)
	}
	select {
	case got := <-received:
		if got.authorization != "Bearer test-metric" || got.contentType != "application/x-protobuf" || got.bytes == 0 {
			t.Fatalf("invalid metric export: %+v", got)
		}
	default:
		t.Fatal("metric exporter sent no request")
	}
}
