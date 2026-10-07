package worker

import (
	"context"
	"log/slog"
	"time"
	"voice-platform/backend/internal/lifecycle/periodic"
	incident "voice-platform/backend/internal/observability/observe_incidents"

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

func NewService(database *pgxpool.Pool, presence finalizeclosedvoicechannel.Presence, events *eventhub.Hub) *finalizeclosedvoicechannel.Service {
	return finalizeclosedvoicechannel.New(finalizepostgres.New(finalizepostgres.NewPoolDatabase(database)), presence, topologyRevisionPublisher{events: events})
}

func Start(parent context.Context, finalizer voiceChannelFinalizer) *periodic.Worker {
	return periodic.Start(parent, 15*time.Second, func(ctx context.Context) { Attempt(ctx, finalizer) })
}

func Attempt(parent context.Context, finalizer voiceChannelFinalizer) {
	ctx, cancel := context.WithTimeout(parent, voiceChannelFinalizationTimeout)
	defer cancel()
	ctx, span := otel.Tracer("boohtacord/voice-workers").Start(ctx, "voice.channel.finalization")
	defer span.End()
	started := time.Now()
	count, err := finalizer.Run(ctx, voiceChannelFinalizationBatchLimit)
	incident.Observe("channel_finalization_worker", started, err)
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
