//go:build tracing_runtime

package ingestclienttraces

import (
	"context"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetrichttp"
	"go.opentelemetry.io/otel/metric"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/metric/metricdata"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestRelayHealthStoredByActualCollector(t *testing.T) {
	collector, prom := privateQA(t, "TRACE_QA_COLLECTOR_URL"), privateQA(t, "TRACE_QA_COLLECTOR_METRICS_URL")
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	exporter, err := otlpmetrichttp.New(ctx, otlpmetrichttp.WithEndpointURL(collector+"/v1/metrics"), otlpmetrichttp.WithInsecure())
	if err != nil {
		t.Fatal(err)
	}
	defer exporter.Shutdown(ctx)
	reader := sdkmetric.NewManualReader()
	provider := sdkmetric.NewMeterProvider(sdkmetric.WithReader(reader))
	defer provider.Shutdown(ctx)
	meter := provider.Meter("boohtacord/relay")
	oldRequests, oldLatency, oldFreshness, oldRecords := relayRequests, relayLatency, relayFreshness, relayRecords
	defer func() {
		relayRequests, relayLatency, relayFreshness, relayRecords = oldRequests, oldLatency, oldFreshness, oldRecords
	}()
	relayRequests, _ = meter.Int64Counter("boohtacord.telemetry.relay.requests")
	relayLatency, _ = meter.Float64Histogram("boohtacord.telemetry.relay.duration", metric.WithUnit("s"))
	relayFreshness, _ = meter.Int64Gauge("boohtacord.telemetry.relay.last_accept", metric.WithUnit("s"))
	relayRecords, _ = meter.Int64Counter("boohtacord.telemetry.relay.records")
	handler := withRelayHealth(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		accepted(w, batchResult{Accepted: 1})
		observeBatch(r.Context(), batchResult{Accepted: 1})
	}))
	handler.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest("POST", "/synthetic", nil))
	var data metricdata.ResourceMetrics
	if err := reader.Collect(ctx, &data); err != nil {
		t.Fatal(err)
	}
	if err := exporter.Export(ctx, &data); err != nil {
		t.Fatal(err)
	}
	client := &http.Client{Timeout: 2 * time.Second, Transport: &http.Transport{Proxy: nil}}
	for ctx.Err() == nil {
		response, err := client.Get(prom + "/metrics")
		if err == nil {
			body, _ := io.ReadAll(io.LimitReader(response.Body, 1<<20))
			response.Body.Close()
			text := string(body)
			if strings.Contains(text, "boohtacord_telemetry_relay_last_accept_seconds") && strings.Contains(text, "boohtacord_telemetry_relay_records_total") {
				for _, line := range strings.Split(text, "\n") {
					if strings.HasPrefix(line, "boohtacord_telemetry_relay_") && (strings.Contains(line, "user_id") || strings.Contains(line, "session_id") || strings.Contains(line, "flow_id")) {
						t.Fatal("private ID used as metric label")
					}
				}
				t.Log("actual Collector health instruments: records_total, last_accept_seconds; fixed labels")
				return
			}
		}
		time.Sleep(250 * time.Millisecond)
	}
	t.Fatal("health instruments absent from actual Collector exporter")
}
