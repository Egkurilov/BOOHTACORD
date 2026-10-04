package observeusage

import (
	"context"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
	"time"
)

func RegisterMetrics(meter metric.Meter, store Store, tracker *Tracker, now func() time.Time) (func() error, error) {
	names := []string{"registered", "registrations", "daily_active", "previous_day_complete", "collection_success", "collection_started_seconds", "activity_write_failures", "collected_at_seconds"}
	gauges := make([]metric.Int64ObservableGauge, len(names))
	instruments := make([]metric.Observable, len(names))
	for i, name := range names {
		gauge, err := meter.Int64ObservableGauge("boohtacord.users." + name)
		if err != nil {
			return nil, err
		}
		gauges[i], instruments[i] = gauge, gauge
	}
	registration, err := meter.RegisterCallback(func(ctx context.Context, observer metric.Observer) error {
		observer.ObserveInt64(gauges[6], tracker.failures.Load())
		bounded, cancel := context.WithTimeout(ctx, time.Second)
		defer cancel()
		at := now()
		observer.ObserveInt64(gauges[7], at.Unix())
		snapshot, err := store.Snapshot(bounded, at)
		if err != nil {
			observer.ObserveInt64(gauges[4], 0)
			return nil
		}
		observer.ObserveInt64(gauges[4], 1)
		observer.ObserveInt64(gauges[0], snapshot.Users)
		observer.ObserveInt64(gauges[5], snapshot.StartedAt.Unix())
		complete := int64(0)
		if !snapshot.StartedAt.After(Day(at).AddDate(0, 0, -1)) {
			complete = 1
		}
		observer.ObserveInt64(gauges[3], complete)
		for _, period := range []struct {
			name                  string
			registrations, active int64
		}{
			{"today", snapshot.RegistrationsToday, snapshot.ActiveToday},
			{"yesterday", snapshot.RegistrationsYesterday, snapshot.ActiveYesterday},
		} {
			attributes := metric.WithAttributes(attribute.String("period", period.name))
			observer.ObserveInt64(gauges[1], period.registrations, attributes)
			observer.ObserveInt64(gauges[2], period.active, attributes)
		}
		return nil
	}, instruments...)
	if err != nil {
		return nil, err
	}
	return registration.Unregister, nil
}
