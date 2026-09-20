package dispatchvoicesfurevocation

import (
	"context"
	"testing"
)

func TestDispatchPendingReturnsBoundedDispatchResult(t *testing.T) {
	dispatcher := &fakeDispatcher{result: Result{Confirmed: 2, Pending: 1}}
	result, err := DispatchPending(context.Background(), dispatcher)
	if err != nil || result != dispatcher.result || dispatcher.limit != 100 || !dispatcher.hasDeadline {
		t.Fatalf("result = %#v, error = %v, dispatcher = %#v", result, err, dispatcher)
	}
}

type fakeDispatcher struct {
	limit       int
	hasDeadline bool
	result      Result
}

func (dispatcher *fakeDispatcher) Dispatch(context context.Context, limit int) (Result, error) {
	_, dispatcher.hasDeadline = context.Deadline()
	dispatcher.limit = limit
	return dispatcher.result, nil
}
