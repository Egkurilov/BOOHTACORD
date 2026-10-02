package workerruntime

import (
	"context"
	"errors"
	"testing"
	sfurevocationworker "voice-platform/backend/internal/media/dispatch_voice_sfu_revocation/worker"
	notificationworker "voice-platform/backend/internal/voice/notify_lease_revocation/worker"

	dispatchvoicesfurevocation "voice-platform/backend/internal/media/dispatch_voice_sfu_revocation"
)

func TestAttemptRecordsAggregateDispatchOutcome(t *testing.T) {
	observer := &fakeVoiceSFUObserver{}
	sfurevocationworker.Attempt(context.Background(), dispatcherFunc(func(context.Context, int) (dispatchvoicesfurevocation.Result, error) {
		return dispatchvoicesfurevocation.Result{Confirmed: 2, Pending: 1}, dispatchvoicesfurevocation.ErrPending
	}), observer)
	if observer.confirmed != 2 || observer.pending != 1 || observer.failed {
		t.Fatalf("observer = %#v", observer)
	}
}

func TestAttemptRecordsOnlyFailureForNonRetryDispatchError(t *testing.T) {
	observer := &fakeVoiceSFUObserver{}
	sfurevocationworker.Attempt(context.Background(), dispatcherFunc(func(context.Context, int) (dispatchvoicesfurevocation.Result, error) {
		return dispatchvoicesfurevocation.Result{}, errors.New("private database topology")
	}), observer)
	if observer.confirmed != 0 || observer.pending != 0 || !observer.failed {
		t.Fatalf("observer = %#v", observer)
	}
}

func TestLeaseNotificationDispatchUsesBoundedIndependentBatch(t *testing.T) {
	notifier := &fakeLeaseNotifier{}
	notificationworker.Attempt(context.Background(), notifier)
	if notifier.limit != 100 || !notifier.hasDeadline || notifier.calls != 1 {
		t.Fatalf("notifier = %#v", notifier)
	}
	sfurevocationworker.Attempt(context.Background(), dispatcherFunc(func(context.Context, int) (dispatchvoicesfurevocation.Result, error) {
		return dispatchvoicesfurevocation.Result{Pending: 1}, dispatchvoicesfurevocation.ErrPending
	}), &fakeVoiceSFUObserver{})
	if notifier.calls != 1 {
		t.Fatal("SFU pending status changed notification dispatch")
	}
}

type fakeLeaseNotifier struct {
	limit       int
	hasDeadline bool
	calls       int
}

func (notifier *fakeLeaseNotifier) Dispatch(context context.Context, limit int) (int, error) {
	notifier.limit = limit
	_, notifier.hasDeadline = context.Deadline()
	notifier.calls++
	return 1, nil
}

type dispatcherFunc func(context.Context, int) (dispatchvoicesfurevocation.Result, error)

func (function dispatcherFunc) Dispatch(context context.Context, limit int) (dispatchvoicesfurevocation.Result, error) {
	return function(context, limit)
}

type fakeVoiceSFUObserver struct {
	confirmed int
	failed    bool
	pending   int
}

func (observer *fakeVoiceSFUObserver) ObserveVoiceSFURevocation(confirmed, pending int, failed bool) {
	observer.confirmed, observer.pending, observer.failed = confirmed, pending, failed
}
