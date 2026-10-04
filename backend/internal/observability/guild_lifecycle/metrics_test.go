package guildlifecycle

import (
	"context"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/metric/metricdata"
	tracenoop "go.opentelemetry.io/otel/trace/noop"
	"testing"
)

type lifecycleCounts struct{ settings, welcome int }

func (c *lifecycleCounts) GuildSettingsUpdate(string) { c.settings++ }
func (c *lifecycleCounts) RegistrationWelcome(string) { c.welcome++ }

func TestOTelLifecycleCountersAreBoundedAndFinishedOnce(t *testing.T) {
	reader := sdkmetric.NewManualReader()
	provider := sdkmetric.NewMeterProvider(sdkmetric.WithReader(reader))
	defer provider.Shutdown(context.Background())
	counts := &lifecycleCounts{}
	observer := New(tracenoop.NewTracerProvider().Tracer("test"), provider.Meter("test"), counts)
	details := Details{UserID: "PRIVATE_USER", UserName: "PRIVATE_NAME", ChannelID: "PRIVATE_CHANNEL", MessageID: "PRIVATE_MESSAGE", PhraseID: "critical_success", Revision: 99, ChangedFields: []string{"name"}}
	_, settings := observer.StartSettings(t.Context())
	settings.Finish("PRIVATE_UNBOUNDED_OUTCOME", details)
	settings.Finish("success", details)
	_, welcome := observer.StartWelcome(t.Context())
	welcome.Finish("skipped_disabled", details)
	welcome.Finish("failed", details)
	if counts.settings != 1 || counts.welcome != 1 {
		t.Fatal("duplicate lifecycle outcome")
	}
	var data metricdata.ResourceMetrics
	if err := reader.Collect(t.Context(), &data); err != nil {
		t.Fatal(err)
	}
	expected := map[string]string{"voice_platform_guild_settings_updates": "failed", "voice_platform_registration_welcome": "skipped_disabled"}
	for _, scope := range data.ScopeMetrics {
		for _, metric := range scope.Metrics {
			outcome, known := expected[metric.Name]
			if !known {
				t.Fatal("unexpected lifecycle metric")
			}
			sum, ok := metric.Data.(metricdata.Sum[int64])
			if !ok || len(sum.DataPoints) != 1 {
				t.Fatal("unbounded metric series")
			}
			point := sum.DataPoints[0]
			value, ok := point.Attributes.Value("outcome")
			if !ok || value.AsString() != outcome || point.Attributes.Len() != 1 || point.Value != 1 {
				t.Fatal("private labels or duplicate outcome")
			}
			delete(expected, metric.Name)
		}
	}
	if len(expected) != 0 {
		t.Fatal("missing lifecycle instrument")
	}
	for _, attr := range data.Resource.Attributes() {
		if attr.Key == "user.id" || attr.Key == "user.name" || attr.Key == "channel.id" || attr.Key == "message.id" {
			t.Fatal("identity on metric resource")
		}
	}
}
