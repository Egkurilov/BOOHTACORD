package main

import (
	"context"
	"errors"
	"log/slog"
	"time"

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
	emitted, err := notifier.Dispatch(context, voiceLeaseNotificationBatchLimit)
	if err != nil {
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
	result, err := dispatchvoicesfurevocation.DispatchPending(context, dispatcher)
	observer.ObserveVoiceSFURevocation(result.Confirmed, result.Pending, err != nil && !errors.Is(err, dispatchvoicesfurevocation.ErrPending))
	if err != nil {
		slog.Warn("voice sfu revocation dispatch did not complete", "confirmed", result.Confirmed, "pending", result.Pending)
	}
}
