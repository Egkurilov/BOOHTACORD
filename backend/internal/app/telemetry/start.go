package telemetry

import (
	"context"
	"errors"
	"time"
	"voice-platform/backend/internal/app/lifecycle"
	startmetrics "voice-platform/backend/internal/observability/start_metrics"
	starttracing "voice-platform/backend/internal/observability/start_tracing"
)

type StartFunc func(context.Context) (func(context.Context) error, error)

func Start(ctx context.Context) (lifecycle.Stop, error) {
	return start(ctx, starttracing.Start, startmetrics.Start)
}

func start(ctx context.Context, tracing, metrics StartFunc) (lifecycle.Stop, error) {
	stopTracing, err := tracing(ctx)
	if err != nil {
		return nil, err
	}
	stopMetrics, err := metrics(ctx)
	if err != nil {
		cleanup, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		return nil, errors.Join(err, stopTracing(cleanup))
	}
	return func(ctx context.Context) error { return errors.Join(stopMetrics(ctx), stopTracing(ctx)) }, nil
}
