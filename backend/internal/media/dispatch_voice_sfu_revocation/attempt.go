package dispatchvoicesfurevocation

import (
	"context"
	"errors"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/trace"
	"time"
	removelivekitparticipant "voice-platform/backend/internal/media/remove_livekit_participant"
	cause "voice-platform/backend/internal/observability/causal_reference"
)

func (service Service) attempt(ctx context.Context, item Item) (confirmed bool, err error) {
	original := cause.Decode(item.TraceCause)
	options := []trace.SpanStartOption{trace.WithNewRoot(), trace.WithSpanKind(trace.SpanKindConsumer)}
	if original.Valid() {
		options = append(options, trace.WithLinks(original.Link()))
	}
	ctx, span := otel.Tracer("boohtacord/voice-workers").Start(ctx, "voice.sfu_revocation.attempt", options...)
	defer span.End()
	span.SetAttributes(attribute.Int("app.worker.attempt", item.Attempt), attribute.String("app.flow.record", "terminal"), attribute.String("app.flow.stage", "dependency"), attribute.String("app.provenance", "server_confirmed"))
	if original.FlowID != "" {
		span.SetAttributes(attribute.String("app.flow.id", original.FlowID), attribute.Int("app.schema.version", 1))
	}
	if !item.RequestedAt.IsZero() && time.Since(item.RequestedAt) >= 0 {
		span.SetAttributes(attribute.Float64("app.worker.queue_wait_ms", float64(time.Since(item.RequestedAt).Milliseconds())))
	}
	removeError := service.remover.Remove(ctx, item.LeaseID, item.ChannelID)
	if removeError == nil || errors.Is(removeError, removelivekitparticipant.ErrParticipantAbsent) {
		result := "sfu_api_ack"
		if errors.Is(removeError, removelivekitparticipant.ErrParticipantAbsent) {
			result = "participant_absent"
		}
		span.SetAttributes(attribute.String("app.worker.result", result))
		if err = service.store.Confirm(ctx, item); err != nil {
			span.SetStatus(codes.Error, "confirm_failed")
			span.SetAttributes(attribute.String("app.flow.outcome", "failed"), attribute.String("app.worker.result", "confirmation_failed"))
			return false, err
		}
		span.SetAttributes(attribute.String("app.flow.outcome", "success"))
		return true, nil
	}
	span.SetStatus(codes.Error, "dependency_unavailable")
	span.SetAttributes(attribute.String("app.flow.outcome", "failed"), attribute.String("app.worker.result", "retry"))
	err = service.store.Retry(ctx, item, "SFU_UNAVAILABLE")
	return false, err
}
