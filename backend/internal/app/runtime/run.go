// Package app is the API composition entrypoint. Domain packages own behavior.
package app

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"time"
	"voice-platform/backend/internal/app/lifecycle"
	"voice-platform/backend/internal/app/telemetry"
	workerruntime "voice-platform/backend/internal/app/worker_runtime"
	runtimeconfig "voice-platform/backend/internal/config/runtime"
	"voice-platform/backend/internal/database/pool"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
)

func Run(ctx context.Context) (result error) {
	configuration, err := runtimeconfig.Load(os.Getenv)
	if err != nil {
		return err
	}
	resources := lifecycle.Stack{}
	defer func() {
		shutdown, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		result = errors.Join(result, resources.Close(shutdown))
	}()
	stopTelemetry, err := telemetry.Start(ctx)
	if err != nil {
		return err
	}
	resources.Add(stopTelemetry)
	database, err := pool.Open(ctx, configuration.DatabaseURL)
	if err != nil {
		return err
	}
	resources.Add(func(ctx context.Context) error { return lifecycle.Wait(ctx, database.Close) })
	events, stopRealtime := workerruntime.StartRealtime(ctx, database)
	resources.Add(stopRealtime)
	metrics := httpmetrics.New()
	handler, err := routes(database, configuration, events, metrics)
	if err != nil {
		return err
	}
	resources.Add(workerruntime.StartVoice(ctx, database, configuration, metrics, events))
	server := &http.Server{Addr: configuration.Address, Handler: handler, ReadHeaderTimeout: 5 * time.Second}
	slog.Info("api listening", "address", configuration.Address)
	return lifecycle.Serve(ctx, server)
}
