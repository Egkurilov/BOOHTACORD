package observeusage

import (
	"context"
	"errors"
	sdk "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/metric/metricdata"
	"testing"
	"time"
)

func TestMetricsAreAggregatesAndDoNotInventPreviousDayHistory(t *testing.T) {
	now := time.Date(2026, 10, 4, 21, 5, 0, 0, time.UTC)
	store := &fakeStore{snapshot: Snapshot{Users: 20, RegistrationsToday: 2, ActiveToday: 5, StartedAt: now.Add(-time.Hour)}}
	reader := sdk.NewManualReader()
	provider := sdk.NewMeterProvider(sdk.WithReader(reader))
	defer provider.Shutdown(context.Background())
	stop, err := RegisterMetrics(provider.Meter("test"), store, NewTracker(store, time.Now), func() time.Time { return now })
	if err != nil {
		t.Fatal(err)
	}
	defer stop()
	values := collect(t, reader)
	if values["boohtacord.users.registered"] != 20 || values["boohtacord.users.daily_active:today"] != 5 || values["boohtacord.users.previous_day_complete"] != 0 {
		t.Fatalf("wrong aggregate metrics: %v", values)
	}
	store.snapshot.StartedAt = Day(now).AddDate(0, 0, -2)
	if collect(t, reader)["boohtacord.users.previous_day_complete"] != 1 {
		t.Fatal("complete previous day missing")
	}
	store.err = errors.New("database offline")
	values = collect(t, reader)
	if values["boohtacord.users.collection_success"] != 0 {
		t.Fatal("failed collection appears healthy")
	}
	if _, ok := values["boohtacord.users.registered"]; ok {
		t.Fatal("failed read emitted a false user count")
	}
}

func collect(t *testing.T, reader *sdk.ManualReader) map[string]int64 {
	t.Helper()
	var data metricdata.ResourceMetrics
	if err := reader.Collect(context.Background(), &data); err != nil {
		t.Fatal(err)
	}
	values := map[string]int64{}
	for _, scope := range data.ScopeMetrics {
		for _, m := range scope.Metrics {
			gauge, ok := m.Data.(metricdata.Gauge[int64])
			if !ok {
				continue
			}
			for _, point := range gauge.DataPoints {
				name := m.Name
				for _, attr := range point.Attributes.ToSlice() {
					if attr.Key != "period" || (attr.Value.AsString() != "today" && attr.Value.AsString() != "yesterday") {
						t.Fatal("unbounded metric label")
					}
					name += ":" + attr.Value.AsString()
				}
				values[name] = point.Value
			}
		}
	}
	return values
}
