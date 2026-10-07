package aggregate

import (
	"context"
	"fmt"
	"strings"
	"testing"

	"go.opentelemetry.io/otel/sdk/metric/metricdata"
)

func TestLabelsAndRetainedPopulationsAreBounded(t *testing.T) {
	m, reader := fixture(t)
	ctx := context.Background()
	for _, platform := range []string{"desktop_web", "ios_native", "macos_native"} {
		for _, direction := range []string{"sender", "receiver"} {
			m.Observe(ctx, Sample{Platform: platform, Direction: direction, Quality: "private-user", Adaptation: "private-track"})
		}
	}
	for _, bad := range []Sample{{Platform: "private-room", Direction: "sender"}, {Platform: "desktop_web", Direction: "connection"}} {
		m.Observe(ctx, bad)
	}
	if len(m.latest) != 6 {
		t.Fatalf("unbounded retention=%v", len(m.latest))
	}
	for _, metric := range collect(t, reader) {
		if sum, ok := metric.Data.(metricdata.Sum[int64]); ok {
			for _, point := range sum.DataPoints {
				if strings.Contains(fmt.Sprint(point.Attributes.ToSlice()), "private") {
					t.Fatal("private label exported")
				}
				for _, label := range point.Attributes.ToSlice() {
					switch string(label.Key) {
					case "platform", "direction", "source", "age_provenance", "freshness", "field", "availability", "stage", "role", "state", "quality", "reason":
					default:
						t.Fatalf("unexpected label %s", label.Key)
					}
				}
			}
		}
	}
}

func TestRatiosAndLossRejectInvalidPairs(t *testing.T) {
	m, reader := fixture(t)
	ctx := context.Background()
	zero, fps, loss, badWindow := 0.0, 30.0, 1.0, 1.0
	r := Sample{Platform: "desktop_web", Direction: "sender", TargetFPS: &zero, Encoded: &fps, Loss: &loss, LossWindow: &badWindow}
	m.Observe(ctx, r)
	data := collect(t, reader)
	for _, name := range []string{"fps_target_ratio", "packet_loss_percent"} {
		if _, exists := data["boohtacord_media_"+name]; exists {
			t.Fatalf("invalid pair produced %s", name)
		}
	}
}

func TestCallerMutationCannotAlterLatestAge(t *testing.T) {
	m, reader := fixture(t)
	age := 250.0
	m.Observe(context.Background(), Sample{Platform: "desktop_web", Direction: "sender", Age: &age})
	age = 15000
	d := collect(t, reader)["boohtacord_media_sample_age_seconds"].Data.(metricdata.Gauge[float64]).DataPoints[0]
	if d.Value > 1 {
		t.Fatal("retained caller pointer")
	}
}
