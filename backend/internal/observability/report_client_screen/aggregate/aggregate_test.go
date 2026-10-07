package aggregate

import (
	"context"
	"testing"
	"time"

	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/metric/metricdata"
)

func fixture(t *testing.T) (*Metrics, *sdkmetric.ManualReader) {
	t.Helper()
	reader := sdkmetric.NewManualReader()
	provider := sdkmetric.NewMeterProvider(sdkmetric.WithReader(reader))
	t.Cleanup(func() { _ = provider.Shutdown(context.Background()) })
	return New(provider.Meter("test")), reader
}

func collect(t *testing.T, reader *sdkmetric.ManualReader) map[string]metricdata.Metrics {
	t.Helper()
	var data metricdata.ResourceMetrics
	if err := reader.Collect(context.Background(), &data); err != nil {
		t.Fatal(err)
	}
	result := map[string]metricdata.Metrics{}
	for _, scope := range data.ScopeMetrics {
		for _, value := range scope.Metrics {
			result[value.Name] = value
		}
	}
	return result
}

func TestMissingAndZeroLossHaveDifferentObservations(t *testing.T) {
	m, reader := fixture(t)
	age, zero, window := 200.0, 0.0, 10000.0
	r := Sample{Platform: "desktop_web", Direction: "receiver", Age: &age}
	m.Observe(context.Background(), r)
	if _, exists := collect(t, reader)["boohtacord_media_packet_loss_percent"]; exists {
		t.Fatal("missing loss became zero")
	}
	r.Loss, r.LossWindow = &zero, &window
	m.Observe(context.Background(), r)
	d := collect(t, reader)["boohtacord_media_packet_loss_percent"].Data.(metricdata.Histogram[float64]).DataPoints
	if len(d) != 1 || d[0].Count != 1 || d[0].Sum != 0 {
		t.Fatalf("loss=%+v", d)
	}
	r.LossWindow = nil
	m.Observe(context.Background(), r)
	if collect(t, reader)["boohtacord_media_packet_loss_percent"].Data.(metricdata.Histogram[float64]).DataPoints[0].Count != 1 {
		t.Fatal("windowless loss observed")
	}
}

func TestStageRatiosUsePairedTargetsAndNeverSumFPS(t *testing.T) {
	m, reader := fixture(t)
	age, fps, target := 100.0, 30.0, 60.0
	r := Sample{Platform: "desktop_web", Direction: "receiver", Age: &age, Decoded: &fps, Presented: &fps}
	m.Observe(context.Background(), r)
	if _, exists := collect(t, reader)["boohtacord_media_fps_target_ratio"]; exists {
		t.Fatal("missing target became ratio")
	}
	r.TargetFPS = &target
	m.Observe(context.Background(), r)
	d := collect(t, reader)["boohtacord_media_fps_target_ratio"].Data.(metricdata.Histogram[float64]).DataPoints
	if len(d) != 2 {
		t.Fatalf("stages=%+v", d)
	}
	for _, p := range d {
		if p.Count != 1 || p.Sum != 0.5 {
			t.Fatalf("ratio=%+v", p)
		}
	}
}

func TestStaleLegacyAndFreshnessRemainDistinct(t *testing.T) {
	m, reader := fixture(t)
	now := time.Unix(1000, 0)
	m.now = func() time.Time { return now }
	fps, stale := 30.0, 6000.0
	r := Sample{Platform: "desktop_web", Direction: "sender", Encoded: &fps, Age: &stale}
	m.Observe(context.Background(), r)
	if _, exists := collect(t, reader)["boohtacord_media_fps"]; exists {
		t.Fatal("stale quality observed")
	}
	r.Age = nil
	m.Observe(context.Background(), r)
	d := collect(t, reader)
	p := d["boohtacord_media_fps"].Data.(metricdata.Histogram[float64]).DataPoints[0]
	value, _ := p.Attributes.Value("age_provenance")
	if value.AsString() != "legacy" {
		t.Fatal("legacy report claimed fresh age")
	}
	now = now.Add(61 * time.Second)
	d = collect(t, reader)
	if got := d["boohtacord_media_report_received_seconds"].Data.(metricdata.Gauge[float64]).DataPoints[0].Value; got != 1000 {
		t.Fatalf("receipt=%v", got)
	}
	if got := d["boohtacord_media_sample_age_known"].Data.(metricdata.Gauge[int64]).DataPoints[0].Value; got != 0 {
		t.Fatal("missing age claimed known")
	}
}
