package telemetry

import (
	"context"
	"errors"
	"testing"
)

func TestMetricsStartupFailureShutsDownAlreadyStartedTracing(t *testing.T) {
	closed := false
	failure := errors.New("metrics startup failed")
	tracing := func(context.Context) (func(context.Context) error, error) {
		return func(ctx context.Context) error {
			closed = true
			if _, ok := ctx.Deadline(); !ok {
				t.Error("cleanup must be bounded")
			}
			return nil
		}, nil
	}
	metrics := func(context.Context) (func(context.Context) error, error) { return nil, failure }
	stop, err := start(t.Context(), tracing, metrics)
	if stop != nil || !errors.Is(err, failure) || !closed {
		t.Fatal("startup leaked tracing or discarded its error")
	}
}
