package worker

import (
	"context"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	"log/slog"
	"time"
	"voice-platform/backend/internal/lifecycle/periodic"
)

const voiceLeaseNotificationBatchLimit = 100
const voiceLeaseNotificationTimeout = 5 * time.Second

type Notifier interface {
	Dispatch(context.Context, int) (int, error)
}

func Start(parent context.Context, notifier Notifier) *periodic.Worker {
	return periodic.Start(parent, 15*time.Second, func(ctx context.Context) { Attempt(ctx, notifier) })
}

func Attempt(parent context.Context, notifier Notifier) {
	context, cancel := context.WithTimeout(parent, voiceLeaseNotificationTimeout)
	defer cancel()
	context, span := otel.Tracer("boohtacord/voice-workers").Start(context, "voice.lease_notification.dispatch")
	defer span.End()
	emitted, err := notifier.Dispatch(context, voiceLeaseNotificationBatchLimit)
	span.SetAttributes(attribute.Int("voice.notifications.emitted", emitted))
	if err != nil {
		span.SetStatus(codes.Error, "notification dispatch failed")
		slog.Warn("voice lease revocation notification dispatch did not complete", "emitted", emitted)
	}
}
