package flowstage

import (
	"context"
	"errors"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/trace"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	bindflow "voice-platform/backend/internal/observability/bind_flow"
	correlatesession "voice-platform/backend/internal/observability/correlate_session"
)

func Begin(ctx context.Context, name, stage string, options ...trace.SpanStartOption) (context.Context, trace.Span) {
	ctx, span := otel.Tracer("boohtacord/flow").Start(ctx, name, options...)
	if flow, ok := bindflow.From(ctx); ok {
		span.SetAttributes(flow.Attributes()...)
	}
	if principal, ok := sessionapi.PrincipalFrom(ctx); ok {
		span.SetAttributes(correlatesession.Attributes(principal.AccountID, principal.SessionDigest)...)
	}
	span.SetAttributes(attribute.Int("app.schema.version", 1), attribute.String("app.flow.record", "terminal"), attribute.String("app.flow.stage", stage), attribute.String("app.provenance", "server_confirmed"))
	return ctx, span
}

type Rejection struct {
	Error  error
	Reason string
}

func Reject(err error, reason string) Rejection { return Rejection{err, reason} }
func End(span trace.Span, err error, rejections ...Rejection) {
	outcome, reason := "success", "none"
	if err != nil {
		outcome, reason = "failed", "dependency"
		span.SetStatus(codes.Error, "operation_failed")
		if errors.Is(err, context.DeadlineExceeded) {
			outcome, reason = "timeout", "deadline"
		}
		if errors.Is(err, context.Canceled) {
			outcome, reason = "cancelled", "disposed"
		}
		for _, rejection := range rejections {
			if errors.Is(err, rejection.Error) {
				outcome, reason = "rejected", rejection.Reason
				break
			}
		}
	}
	span.SetAttributes(attribute.String("app.flow.outcome", outcome), attribute.String("app.flow.reason", reason))
	span.End()
}
func Storage(ctx context.Context, result string) {
	if result == "committed" || result == "replayed" || result == "rejected" {
		trace.SpanFromContext(ctx).SetAttributes(attribute.String("app.storage.result", result))
	}
}
func Mark(ctx context.Context, stage, outcome string) {
	trace.SpanFromContext(ctx).AddEvent("app.server.stage", trace.WithAttributes(attribute.String("app.flow.stage", stage), attribute.String("app.flow.outcome", outcome)))
}
