package main

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"
	dispatchvoicesfurevocation "voice-platform/backend/internal/media/dispatch_voice_sfu_revocation"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func startVoiceBackgroundServices(database *pgxpool.Pool, configuration runtimeConfiguration, metrics *httpmetrics.Recorder, events *eventhub.Hub) func() {
	sfuStop := startVoiceSFURevocationWorker(context.Background(), dispatchvoicesfurevocation.New(
		dispatchvoicesfurevocation.NewRepository(dispatchvoicesfurevocation.NewPoolDatabase(database)),
		configuration.roomRemover,
	), metrics)
	finalizationStop := startVoiceChannelFinalizationWorker(context.Background(),
		newVoiceChannelFinalizer(database, configuration.mediaSnapshot, events))
	return func() {
		finalizationStop()
		sfuStop()
	}
}
