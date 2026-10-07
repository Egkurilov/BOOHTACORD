package worker

import (
	"context"
	"errors"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	"log/slog"
	"time"
	"voice-platform/backend/internal/lifecycle/periodic"
	dispatchvoicesfurevocation "voice-platform/backend/internal/media/dispatch_voice_sfu_revocation"
	incident "voice-platform/backend/internal/observability/observe_incidents"
)

type Observer interface {
	ObserveVoiceSFURevocation(confirmed, pending int, failed bool)
}

func Start(parent context.Context, dispatcher dispatchvoicesfurevocation.Dispatcher, observer Observer) *periodic.Worker {
	return periodic.Start(parent, 15*time.Second, func(ctx context.Context) { Attempt(ctx, dispatcher, observer) })
}

func Attempt(context context.Context, dispatcher dispatchvoicesfurevocation.Dispatcher, observer Observer) {
	context, span := otel.Tracer("boohtacord/voice-workers").Start(context, "voice.sfu_revocation.dispatch")
	defer span.End()
	started := time.Now()
	result, err := dispatchvoicesfurevocation.DispatchPending(context, dispatcher)
	observedErr := err
	if errors.Is(err, dispatchvoicesfurevocation.ErrPending) {
		observedErr = nil
	}
	incident.Observe("sfu_revocation_worker", started, observedErr)
	span.SetAttributes(attribute.Int("voice.revocations.confirmed", result.Confirmed), attribute.Int("voice.revocations.pending", result.Pending))
	observer.ObserveVoiceSFURevocation(result.Confirmed, result.Pending, err != nil && !errors.Is(err, dispatchvoicesfurevocation.ErrPending))
	if err != nil && !errors.Is(err, dispatchvoicesfurevocation.ErrPending) {
		span.SetStatus(codes.Error, "SFU revocation failed")
	}
	if err != nil {
		slog.Warn("voice sfu revocation dispatch did not complete", "confirmed", result.Confirmed, "pending", result.Pending)
	}
}
