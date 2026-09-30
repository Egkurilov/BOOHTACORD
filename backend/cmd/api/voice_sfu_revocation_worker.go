package main

import (
	"context"
	"errors"
	"log/slog"
	"time"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"

	dispatchvoicesfurevocation "voice-platform/backend/internal/media/dispatch_voice_sfu_revocation"
)

const voiceSFURevocationPollInterval = 15 * time.Second
const voiceLeaseNotificationBatchLimit = 100
const voiceLeaseNotificationTimeout = 5 * time.Second

type voiceLeaseRevocationNotifier interface {
	Dispatch(context.Context, int) (int, error)
}

func startVoiceLeaseRevocationNotificationWorker(parent context.Context, notifier voiceLeaseRevocationNotifier) context.CancelFunc {
	context, cancel := context.WithCancel(parent)
	go func() {
		attemptVoiceLeaseRevocationNotificationDispatch(context, notifier)
		ticker := time.NewTicker(voiceSFURevocationPollInterval)
		defer ticker.Stop()
		for {
			select {
			case <-context.Done():
				return
			case <-ticker.C:
				attemptVoiceLeaseRevocationNotificationDispatch(context, notifier)
			}
		}
	}()
	return cancel
}

func attemptVoiceLeaseRevocationNotificationDispatch(parent context.Context, notifier voiceLeaseRevocationNotifier) {
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

type voiceSFURevocationObserver interface {
	ObserveVoiceSFURevocation(confirmed, pending int, failed bool)
}

func startVoiceSFURevocationWorker(parent context.Context, dispatcher dispatchvoicesfurevocation.Dispatcher, observer voiceSFURevocationObserver) context.CancelFunc {
	context, cancel := context.WithCancel(parent)
	go func() {
		attemptVoiceSFURevocationDispatch(context, dispatcher, observer)
		ticker := time.NewTicker(voiceSFURevocationPollInterval)
		defer ticker.Stop()
		for {
			select {
			case <-context.Done():
				return
			case <-ticker.C:
				attemptVoiceSFURevocationDispatch(context, dispatcher, observer)
			}
		}
	}()
	return cancel
}

func attemptVoiceSFURevocationDispatch(context context.Context, dispatcher dispatchvoicesfurevocation.Dispatcher, observer voiceSFURevocationObserver) {
	context, span := otel.Tracer("boohtacord/voice-workers").Start(context, "voice.sfu_revocation.dispatch")
	defer span.End()
	result, err := dispatchvoicesfurevocation.DispatchPending(context, dispatcher)
	span.SetAttributes(attribute.Int("voice.revocations.confirmed", result.Confirmed), attribute.Int("voice.revocations.pending", result.Pending))
	observer.ObserveVoiceSFURevocation(result.Confirmed, result.Pending, err != nil && !errors.Is(err, dispatchvoicesfurevocation.ErrPending))
	if err != nil && !errors.Is(err, dispatchvoicesfurevocation.ErrPending) {
		span.SetStatus(codes.Error, "SFU revocation failed")
	}
	if err != nil {
		slog.Warn("voice sfu revocation dispatch did not complete", "confirmed", result.Confirmed, "pending", result.Pending)
	}
}
