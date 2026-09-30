package main

import (
	"context"
	"log/slog"
	"time"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	finalizeclosedvoicechannel "voice-platform/backend/internal/channel/finalize_closed_voice_channel"
	finalizepostgres "voice-platform/backend/internal/channel/finalize_closed_voice_channel/postgres"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

const voiceChannelFinalizationBatchLimit = 20
const voiceChannelFinalizationTimeout = 5 * time.Second

type voiceChannelFinalizer interface {
	Run(context.Context, int) (int, error)
}

func newVoiceChannelFinalizer(database *pgxpool.Pool, presence finalizeclosedvoicechannel.Presence, events *eventhub.Hub) *finalizeclosedvoicechannel.Service {
	return finalizeclosedvoicechannel.New(finalizepostgres.New(finalizepostgres.NewPoolDatabase(database)), presence, topologyRevisionPublisher{events: events})
}

func startVoiceChannelFinalizationWorker(parent context.Context, finalizer voiceChannelFinalizer) context.CancelFunc {
	ctx, cancel := context.WithCancel(parent)
	go func() {
		attemptVoiceChannelFinalization(ctx, finalizer)
		ticker := time.NewTicker(voiceSFURevocationPollInterval)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				attemptVoiceChannelFinalization(ctx, finalizer)
			}
		}
	}()
	return cancel
}

func attemptVoiceChannelFinalization(parent context.Context, finalizer voiceChannelFinalizer) {
	ctx, cancel := context.WithTimeout(parent, voiceChannelFinalizationTimeout)
	defer cancel()
	ctx, span := otel.Tracer("boohtacord/voice-workers").Start(ctx, "voice.channel.finalization")
	defer span.End()
	count, err := finalizer.Run(ctx, voiceChannelFinalizationBatchLimit)
	span.SetAttributes(attribute.Int("voice.channels.finalized", count))
	if err != nil {
		span.SetStatus(codes.Error, "voice channel finalization failed")
		slog.Warn("voice channel finalization did not complete", "finalized", count)
	}
}

type topologyRevisionPublisher struct{ events *eventhub.Hub }

func (publisher topologyRevisionPublisher) PublishTopologyRevision(revision int64) {
	publisher.events.Publish(eventhub.Event{
		EventID: uuid.NewString(), Kind: "channel.updated", OccurredAt: time.Now().UTC(),
		Payload: map[string]any{"revision": revision},
	})
}
