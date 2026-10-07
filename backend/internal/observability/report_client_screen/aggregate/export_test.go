package aggregate

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetrichttp"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	collector "go.opentelemetry.io/proto/otlp/collector/metrics/v1"
	"google.golang.org/protobuf/proto"
)

func TestOTLPPayloadAndOptionalPinnedCollectorNames(t *testing.T) {
	payload := make(chan *collector.ExportMetricsServiceRequest, 1)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		var request collector.ExportMetricsServiceRequest
		if proto.Unmarshal(body, &request) != nil {
			t.Error("invalid OTLP payload")
		}
		payload <- &request
		w.WriteHeader(http.StatusOK)
	}))
	defer server.Close()
	endpoint := os.Getenv("QOE_COLLECTOR_ENDPOINT")
	if endpoint == "" {
		endpoint = server.URL
	}
	if !strings.HasPrefix(endpoint, "http://127.0.0.1:") {
		t.Fatal("collector check requires local loopback")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	exporter, err := otlpmetrichttp.New(ctx, otlpmetrichttp.WithEndpointURL(endpoint))
	if err != nil {
		t.Fatal(err)
	}
	provider := sdkmetric.NewMeterProvider(sdkmetric.WithReader(sdkmetric.NewPeriodicReader(exporter, sdkmetric.WithInterval(time.Hour))))
	defer provider.Shutdown(ctx)
	m := New(provider.Meter("test"))
	width, height, drops := 1920, 1080, int64(3)
	age, fps, target, resolution, bitrate, rtt, jitter, loss, window := 100.0, 30.0, 60.0, 1080.0, 4000.0, 42.0, 10.0, 2.0, 10000.0
	m.Observe(ctx, Sample{Platform: "desktop_web", Direction: "sender", State: "playing", Age: &age,
		Encoded: &fps, TargetFPS: &target, TargetResolution: &resolution, Width: &width, Height: &height,
		Bitrate: &bitrate, RTT: &rtt, Jitter: &jitter, Loss: &loss, LossWindow: &window, Dropped: &drops})
	if err := provider.ForceFlush(ctx); err != nil {
		t.Fatal(err)
	}
	if endpoint == server.URL {
		request := <-payload
		found := false
		for _, resource := range request.ResourceMetrics {
			for _, scope := range resource.ScopeMetrics {
				for _, metric := range scope.Metrics {
					if metric.Name == "boohtacord_media_packet_loss_percent" {
						found = true
					}
				}
			}
		}
		if !found {
			t.Fatal("loss not encoded in OTLP")
		}
		return
	}
	scrape := os.Getenv("QOE_COLLECTOR_SCRAPE")
	if !strings.HasPrefix(scrape, "http://127.0.0.1:") {
		t.Fatal("scrape requires loopback")
	}
	response, err := http.Get(scrape)
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	body, _ := io.ReadAll(response.Body)
	text := string(body)
	for _, expected := range []string{"boohtacord_media_reports_total", "boohtacord_media_fps_bucket", "boohtacord_media_rtt_milliseconds_bucket", "boohtacord_media_packet_loss_percent_bucket", "boohtacord_media_dropped_frames_bucket", "boohtacord_media_sample_age_known"} {
		if !strings.Contains(text, expected) {
			t.Fatalf("pinned collector missing %s: %s", expected, text)
		}
	}
	if destination := os.Getenv("QOE_COLLECTOR_BYTES"); destination != "" {
		if err := os.WriteFile(destination, body, 0600); err != nil {
			t.Fatal(err)
		}
	}
}
