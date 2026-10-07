package aggregate

import (
	"context"
	"testing"

	"go.opentelemetry.io/otel/sdk/metric/metricdata"
)

func TestStaleMissingAndDerivedFieldDenominators(t *testing.T) {
	m, reader := fixture(t)
	age, rtt := 6000.0, 42.0
	m.Observe(context.Background(), Sample{Platform: "desktop_web", Direction: "receiver", State: "waiting_first_frame", Age: &age, RTT: &rtt})
	data := collect(t, reader)["boohtacord_media_field_reports"].Data.(metricdata.Sum[int64])
	counts := map[string]int64{}
	for _, p := range data.DataPoints {
		field, _ := p.Attributes.Value("field")
		availability, _ := p.Attributes.Value("availability")
		stage, _ := p.Attributes.Value("stage")
		counts[field.AsString()+":"+stage.AsString()+":"+availability.AsString()] += p.Value
	}
	for key, count := range map[string]int64{
		"rtt_milliseconds::stale": 1, "jitter_milliseconds::missing": 1,
		"packet_loss_window_milliseconds::missing": 1, "resolution_target_ratio::missing": 1,
		"fps_target_ratio:decoded:missing": 1, "fps_target_ratio:presented:missing": 1,
	} {
		if counts[key] != count {
			t.Fatalf("%s=%d", key, counts[key])
		}
	}
}
