package rosterstreammetrics

import (
	"context"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
	"time"
)

type exports struct {
	callCount   metric.Int64Counter
	active      metric.Int64UpDownCounter
	initial     metric.Int64Counter
	initialTime metric.Float64Histogram
	closed      metric.Int64Counter
	calls       metric.Float64Histogram
}

func newExports() *exports {
	meter := otel.Meter("voice-platform/roster")
	active, _ := meter.Int64UpDownCounter("voice_platform_voice_roster_streams_active")
	initial, _ := meter.Int64Counter("voice_platform_voice_roster_initial_total")
	for _, outcome := range []string{"success", "failure", "canceled"} {
		initial.Add(context.Background(), 0, metric.WithAttributes(attribute.String("outcome", outcome)))
	}
	initialTime, _ := meter.Float64Histogram("voice_platform_voice_roster_initial_seconds", metric.WithUnit("s"), metric.WithExplicitBucketBoundaries(.005, .01, .025, .05, .1, .25, .5, 1, 2.5, 5, 10))
	closed, _ := meter.Int64Counter("voice_platform_voice_roster_stream_ends_total")
	calls, _ := meter.Float64Histogram("voice_platform_sfu_room_service_seconds", metric.WithUnit("s"), metric.WithExplicitBucketBoundaries(.005, .01, .025, .05, .1, .25, .5, 1, 2.5, 5, 10))
	callCount, _ := meter.Int64Counter("voice_platform_sfu_room_service_calls_total")
	return &exports{callCount: callCount, active: active, initial: initial, initialTime: initialTime, closed: closed, calls: calls}
}

func (e *exports) initialAttempt(elapsed time.Duration, outcome string) {
	ctx := context.Background()
	e.initial.Add(ctx, 1, metric.WithAttributes(attribute.String("outcome", outcome)))
	e.initialTime.Record(ctx, elapsed.Seconds())
}
func (e *exports) close(reason string) {
	e.active.Add(context.Background(), -1)
	e.closed.Add(context.Background(), 1, metric.WithAttributes(attribute.String("reason", reason)))
}
func (e *exports) call(method, outcome string, elapsed time.Duration) {
	counterOutcome := "success"
	if outcome != "success" {
		counterOutcome = "failure"
	}
	e.callCount.Add(context.Background(), 1, metric.WithAttributes(attribute.String("method", method), attribute.String("outcome", counterOutcome)))
	e.calls.Record(context.Background(), elapsed.Seconds(), metric.WithAttributes(attribute.String("method", method), attribute.String("outcome", outcome)))
}
