// Package app is the API composition entrypoint. Domain packages own behavior.
package app

import (
	"context"
	"errors"
	"go.opentelemetry.io/otel"
	"log/slog"
	"net/http"
	"os"
	"time"
	"voice-platform/backend/internal/app/lifecycle"
	"voice-platform/backend/internal/app/telemetry"
	workerruntime "voice-platform/backend/internal/app/worker_runtime"
	clientupdates "voice-platform/backend/internal/client_updates/catalog"
	runtimeconfig "voice-platform/backend/internal/config/runtime"
	"voice-platform/backend/internal/database/pool"
	observeusage "voice-platform/backend/internal/identity/observe_usage"
	previewmemory "voice-platform/backend/internal/media/screen_preview/memory"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
	writerlock "voice-platform/backend/internal/storage/acquire_writer_lock"
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
	writer, err := writerlock.Acquire(configuration.AttachmentRoot)
	if err != nil {
		return err
	}
	resources.Add(func(context.Context) error { return writer.Close() })
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
	usageStore := observeusage.NewPostgres(database)
	usage := observeusage.NewTracker(usageStore, time.Now)
	previews := previewmemory.New()
	resources.Add(func(context.Context) error { return previews.Close() })
	stopUsage, err := observeusage.RegisterMetrics(otel.Meter("boohtacord/user-usage"), usageStore, usage, time.Now)
	if err != nil {
		return err
	}
	resources.Add(func(context.Context) error { return stopUsage() })
	events, stopRealtime := workerruntime.StartRealtime(ctx, database)
	resources.Add(stopRealtime)
	metrics := httpmetrics.New()
	updates := clientupdates.NewStore(configuration.ClientUpdateCatalogPath, configuration.ClientUpdateAllowedHosts, metrics)
	updates.Start(ctx)
	handler, err := routes(database, configuration, events, metrics, updates, usage, previews)
	if err != nil {
		return err
	}
	resources.Add(workerruntime.StartVoice(ctx, database, configuration, metrics, events))
	server := &http.Server{Addr: configuration.Address, Handler: handler, ReadHeaderTimeout: 5 * time.Second}
	slog.Info("api listening", "address", configuration.Address)
	return lifecycle.Serve(ctx, server)
}
