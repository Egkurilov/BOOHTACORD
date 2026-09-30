package main

import (
	"context"
	"log/slog"
	"os"
	"time"

	startmetrics "voice-platform/backend/internal/observability/start_metrics"
	starttracing "voice-platform/backend/internal/observability/start_tracing"
)

func startTelemetry() func() {
	stopTracing, err := starttracing.Start(context.Background())
	if err != nil {
		slog.Error("configure tracing", "error", err)
		os.Exit(1)
	}
	stopMetrics, err := startmetrics.Start(context.Background())
	if err != nil {
		slog.Error("configure metrics export", "error", err)
		os.Exit(1)
	}
	return func() {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := stopMetrics(ctx); err != nil {
			slog.Warn("flush metrics failed")
		}
		if err := stopTracing(ctx); err != nil {
			slog.Warn("flush traces failed")
		}
	}
}
