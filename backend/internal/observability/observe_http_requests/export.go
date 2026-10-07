package observehttprequests

import (
	"context"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
	"time"
)

type exports struct {
	requests, operational         metric.Int64Counter
	duration, operationalDuration metric.Float64Histogram
}

func newExports() exports {
	meter := otel.Meter("boohtacord/incident-http")
	requests, _ := meter.Int64Counter("boohtacord.incident.http.requests", metric.WithDescription("Completed HTTP requests by bounded method, route template and status."))
	operational, _ := meter.Int64Counter("boohtacord.incident.operational.requests", metric.WithDescription("Fixed operational completions without trace or request context."))
	duration, _ := meter.Float64Histogram("boohtacord.incident.http.duration", metric.WithDescription("Completed route request duration including failure."), metric.WithUnit("s"), metric.WithExplicitBucketBoundaries(.005, .01, .025, .05, .1, .25, .5, 1, 2.5, 5, 10))
	operationalDuration, _ := meter.Float64Histogram("boohtacord.incident.operational.duration", metric.WithDescription("Operational completion duration; streaming duration is connection lifetime."), metric.WithUnit("s"), metric.WithExplicitBucketBoundaries(.005, .01, .025, .05, .1, .25, .5, 1, 2.5, 5, 10, 30, 60, 300, 900))
	return exports{requests, operational, duration, operationalDuration}
}
func (e exports) observe(method, route, operation, status string, elapsed time.Duration) {
	labels := []attribute.KeyValue{attribute.String("method", method), attribute.String("status", status)}
	// Operational aggregates use a fresh context: no trace, request ID or session correlation.
	ctx := context.Background()
	if operation != "" {
		labels = append(labels, attribute.String("operation", operation))
		e.operational.Add(ctx, 1, metric.WithAttributes(labels...))
		e.operationalDuration.Record(ctx, elapsed.Seconds(), metric.WithAttributes(labels...))
		return
	}
	labels = append(labels, attribute.String("route", route))
	e.requests.Add(ctx, 1, metric.WithAttributes(labels...))
	e.duration.Record(ctx, elapsed.Seconds(), metric.WithAttributes(labels...))
}
