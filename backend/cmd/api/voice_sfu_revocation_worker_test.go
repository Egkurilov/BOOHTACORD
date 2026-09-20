package main

import (
	"context"
	"errors"
	"testing"

	dispatchvoicesfurevocation "voice-platform/backend/internal/media/dispatch_voice_sfu_revocation"
)

func TestAttemptRecordsAggregateDispatchOutcome(t *testing.T) {
	observer := &fakeVoiceSFUObserver{}
	attemptVoiceSFURevocationDispatch(context.Background(), dispatcherFunc(func(context.Context, int) (dispatchvoicesfurevocation.Result, error) {
		return dispatchvoicesfurevocation.Result{Confirmed: 2, Pending: 1}, dispatchvoicesfurevocation.ErrPending
	}), observer)
	if observer.confirmed != 2 || observer.pending != 1 || observer.failed {
		t.Fatalf("observer = %#v", observer)
	}
}

func TestAttemptRecordsOnlyFailureForNonRetryDispatchError(t *testing.T) {
	observer := &fakeVoiceSFUObserver{}
	attemptVoiceSFURevocationDispatch(context.Background(), dispatcherFunc(func(context.Context, int) (dispatchvoicesfurevocation.Result, error) {
		return dispatchvoicesfurevocation.Result{}, errors.New("private database topology")
	}), observer)
	if observer.confirmed != 0 || observer.pending != 0 || !observer.failed {
		t.Fatalf("observer = %#v", observer)
	}
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
