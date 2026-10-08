package watchconnectedparticipants

import (
	"context"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/trace"
	"net/http"
	"time"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
)

type LifecycleObserver interface {
	ObserveVoiceRosterInitial(time.Duration, string)
	OpenVoiceRosterStream()
	CloseVoiceRosterStream(string)
}

func observeInitial(observer FailureObserver, ctx context.Context, elapsed time.Duration, err error) {
	if err != nil && ctx.Err() == nil {
		traceFailure(ctx, err)
	}
	if lifecycle, ok := observer.(LifecycleObserver); ok {
		outcome := "success"
		if err != nil {
			outcome = "internal"
			if roster.FailureStatus(err) == http.StatusServiceUnavailable {
				outcome = "unavailable"
			}
		}
		if ctx.Err() != nil {
			outcome = "canceled"
		}
		lifecycle.ObserveVoiceRosterInitial(elapsed, outcome)
	}
}

func traceFailure(ctx context.Context, err error) {
	trace.SpanFromContext(ctx).AddEvent("voice_roster.failure", trace.WithAttributes(attribute.String("failure_stage", roster.FailureStage(err))))
}

func observeStream(observer FailureObserver) func(string) {
	if lifecycle, ok := observer.(LifecycleObserver); ok {
		lifecycle.OpenVoiceRosterStream()
		return lifecycle.CloseVoiceRosterStream
	}
	return func(string) {}
}

func observeSuccess(observer FailureObserver) {
	if fresh, ok := observer.(interface{ ObserveVoiceRosterSuccess() }); ok {
		fresh.ObserveVoiceRosterSuccess()
	}
}
