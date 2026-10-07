package startmetrics

import (
	"encoding/json"
	"github.com/prometheus/client_golang/prometheus"
	"go.opentelemetry.io/otel"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	collector "go.opentelemetry.io/proto/otlp/collector/metrics/v1"
	"google.golang.org/protobuf/proto"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"
	presence "voice-platform/backend/internal/media/snapshot_livekit_presence"
	dependencies "voice-platform/backend/internal/observability/observe_dependencies"
	observehttp "voice-platform/backend/internal/observability/observe_http_requests"
	incident "voice-platform/backend/internal/observability/observe_incidents"
)

func TestIncidentSignalsExportAsOTLP(t *testing.T) {
	received := make(chan []byte, 4)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		data, _ := io.ReadAll(r.Body)
		received <- data
		w.WriteHeader(200)
	}))
	defer server.Close()
	t.Setenv("OTEL_EXPORTER_OTLP_ENDPOINT", "")
	t.Setenv("OTEL_EXPORTER_OTLP_METRICS_ENDPOINT", server.URL)
	t.Setenv("OTEL_EXPORTER_OTLP_PROTOCOL", "http/protobuf")
	old := otel.GetMeterProvider()
	defer otel.SetMeterProvider(old)
	stop, err := Start(t.Context())
	if err != nil {
		t.Fatal(err)
	}
	defer stop(t.Context())
	metrics := observehttp.New(prometheus.NewRegistry())
	mux := http.NewServeMux()
	mux.HandleFunc("GET /items/{id}", func(http.ResponseWriter, *http.Request) {})
	metrics.Observe(httptest.NewRequest("GET", "/items/private?token=secret", nil), mux, 503, time.Millisecond)
	metrics.Observe(httptest.NewRequest("POST", "/api/v1/telemetry/traces?token=secret", nil), mux, 503, time.Millisecond)
	signals := incident.New()
	signals.Observe("livekit_probe", time.Millisecond, nil)
	signals.SetEnabled("metric_export", true)
	dependencies.ExportSnapshot(presence.Snapshot{Participants: 1, Streams: 1, ScreenStreams: 1})
	if err := otel.GetMeterProvider().(*sdkmetric.MeterProvider).ForceFlush(t.Context()); err != nil {
		t.Fatal(err)
	}
	data := <-received
	if path := os.Getenv("INCIDENT_OTLP_FIXTURE"); path != "" {
		if err := os.WriteFile(path, data, 0600); err != nil {
			t.Fatal(err)
		}
	}
	var request collector.ExportMetricsServiceRequest
	if err := proto.Unmarshal(data, &request); err != nil {
		t.Fatal(err)
	}
	encoded, _ := json.Marshal(&request)
	out := string(encoded)
	for _, want := range []string{"boohtacord.incident.http.requests", "boohtacord.incident.http.duration", "boohtacord.incident.operational.requests", "boohtacord.incident.operational.duration", "boohtacord.incident.api.collection.timestamp", "boohtacord.incident.last.success.timestamp", "boohtacord.incident.livekit.snapshot", "/items/{id}"} {
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
