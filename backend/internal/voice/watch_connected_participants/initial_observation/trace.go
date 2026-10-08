package initialobservation

import (
	"context"
	"errors"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/trace"
	requestid "voice-platform/backend/internal/security/request_id"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
)

// General request tracing skips long-lived SSE. This span ends after the
// bounded initial snapshot and never retains a room, account or dependency text.
func Begin(parent context.Context) (context.Context, func(error)) {
	ctx, span := otel.Tracer("voice-platform/roster").Start(parent, "voice.roster.initial",
		trace.WithAttributes(attribute.String("request_id", requestid.From(parent))))
	return ctx, func(err error) {
		if err != nil && !errors.Is(err, context.Canceled) {
			span.SetStatus(codes.Error, "roster observation unavailable")
			span.AddEvent("voice_roster.failure", trace.WithAttributes(
				attribute.String("failure_stage", roster.FailureStage(err))))
		}
		span.End()
	}
}
