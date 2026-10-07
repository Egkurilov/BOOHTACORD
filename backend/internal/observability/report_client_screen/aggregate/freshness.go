package aggregate

import (
	"context"
	"time"

	"go.opentelemetry.io/otel/metric"
)

type receipt struct {
	sample Sample
	at     time.Time
}

func (m *Metrics) remember(s Sample) {
	// Only bounded strings and copied age are retained, never caller pointers or report bodies.
	copy := Sample{Platform: s.Platform, Direction: s.Direction}
	if number(s.Age, 15000) {
		age := *s.Age
		copy.Age = &age
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	m.latest[s.Platform+":"+s.Direction] = receipt{sample: copy, at: m.now()}
}

func (m *Metrics) registerFreshness(meter metric.Meter) {
	received, _ := meter.Float64ObservableGauge("boohtacord_media_report_received_seconds")
	known, _ := meter.Int64ObservableGauge("boohtacord_media_sample_age_known")
	age, _ := meter.Float64ObservableGauge("boohtacord_media_sample_age_seconds")
	initialAge, _ := meter.Float64ObservableGauge("boohtacord_media_sample_age_at_receipt_seconds")
	_, _ = meter.RegisterCallback(func(ctx context.Context, observer metric.Observer) error {
		m.mu.Lock()
		defer m.mu.Unlock()
		for key, r := range m.latest {
			if m.now().Sub(r.at) > 7*24*time.Hour {
				delete(m.latest, key)
				continue
			}
			attrs := metric.WithAttributes(labels(r.sample)...)
			observer.ObserveFloat64(received, float64(r.at.UnixNano())/1e9, attrs)
			var exists int64
			if r.sample.Age != nil {
				exists = 1
				observer.ObserveFloat64(age, *r.sample.Age/1000+m.now().Sub(r.at).Seconds(), attrs)
				observer.ObserveFloat64(initialAge, *r.sample.Age/1000, attrs)
			}
			observer.ObserveInt64(known, exists, attrs)
		}
		return nil
	}, received, known, age, initialAge)
}
