package observeincidents

import (
	"context"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
	"sync"
	"time"
)

type snapshot struct{ attempt, success, result float64 }
type exports struct {
	mu       sync.Mutex
	latest   map[string]snapshot
	enabled  map[string]float64
	total    metric.Int64Counter
	duration metric.Float64Histogram
}

func newExports() *exports {
	e := &exports{latest: make(map[string]snapshot), enabled: make(map[string]float64)}
	meter := otel.Meter("boohtacord/incidents")
	e.total, _ = meter.Int64Counter("boohtacord.incident.operations", metric.WithDescription("Fixed backend operation attempts by bounded outcome."))
	e.duration, _ = meter.Float64Histogram("boohtacord.incident.operation.duration", metric.WithDescription("Fixed backend operation attempt duration including failure."), metric.WithUnit("s"), metric.WithExplicitBucketBoundaries(.005, .01, .025, .05, .1, .25, .5, 1, 2.5, 5, 10))
	attempt, _ := meter.Float64ObservableGauge("boohtacord.incident.last.attempt.timestamp", metric.WithDescription("Unix timestamp of latest fixed operation attempt."), metric.WithUnit("s"))
	success, _ := meter.Float64ObservableGauge("boohtacord.incident.last.success.timestamp", metric.WithDescription("Unix timestamp of latest successful operation; absent until first success."), metric.WithUnit("s"))
	result, _ := meter.Float64ObservableGauge("boohtacord.incident.last.successful", metric.WithDescription("Whether latest fixed operation attempt succeeded."))
	enabled, _ := meter.Float64ObservableGauge("boohtacord.incident.enabled", metric.WithDescription("Whether fixed exporter is configured; zero means intentionally disabled."))
	stale, _ := meter.Float64ObservableGauge("boohtacord.incident.stale", metric.WithDescription("No successful observation or fixed freshness threshold exceeded."))
	collected, _ := meter.Float64ObservableGauge("boohtacord.incident.api.collection.timestamp", metric.WithDescription("API metric collection Unix timestamp before export."), metric.WithUnit("s"))
	_, _ = meter.RegisterCallback(func(ctx context.Context, o metric.Observer) error {
		o.ObserveFloat64(collected, float64(time.Now().Unix()))
		e.mu.Lock()
		defer e.mu.Unlock()
		for operation, value := range e.enabled {
			o.ObserveFloat64(enabled, value, metric.WithAttributes(attribute.String("operation", operation)))
		}
		for operation, s := range e.latest {
			label := metric.WithAttributes(attribute.String("operation", operation))
			o.ObserveFloat64(attempt, s.attempt, label)
			o.ObserveFloat64(result, s.result, label)
			value := 0.
			if s.success == 0 || float64(time.Now().Unix())-s.success > staleAfter(operation).Seconds() {
				value = 1
			}
			o.ObserveFloat64(stale, value, label)
			if s.success > 0 {
				o.ObserveFloat64(success, s.success, label)
			}
		}
		return nil
	}, attempt, success, result, stale, collected, enabled)
	return e
}
func (e *exports) observe(operation, outcome string, elapsed time.Duration, at float64) {
	labels := metric.WithAttributes(attribute.String("operation", operation), attribute.String("outcome", outcome))
	e.total.Add(context.Background(), 1, labels)
	e.duration.Record(context.Background(), elapsed.Seconds(), labels)
	e.mu.Lock()
	defer e.mu.Unlock()
	s := e.latest[operation]
	s.attempt = at
	s.result = 0
	if outcome == "success" {
		s.success = at
		s.result = 1
	}
	e.latest[operation] = s
}
