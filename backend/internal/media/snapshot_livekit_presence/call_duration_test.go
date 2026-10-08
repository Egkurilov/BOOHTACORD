package snapshotlivekitpresence

import (
	"context"
	"errors"
	"net/http"
	"testing"
	"time"
)

type durationRecord struct{ method, outcome string }

func (o *durationRecord) ObserveSFURoomServiceCall(string, bool) {}
func (o *durationRecord) ObserveSFURoomServiceDuration(method, outcome string, _ time.Duration) {
	o.method = method
	o.outcome = outcome
}

func TestRoomServiceDurationSeparatesHTTPFromTransportTimeoutAndCancel(t *testing.T) {
	for _, test := range []struct {
		response *http.Response
		err      error
		outcome  string
	}{
		{&http.Response{StatusCode: 200}, nil, "success"},
		{&http.Response{StatusCode: 503}, nil, "http_error"},
		{&http.Response{StatusCode: 429}, nil, "overload"},
		{nil, errors.New("private upstream DNS detail"), "transport_error"},
		{nil, context.DeadlineExceeded, "timeout"},
		{nil, context.Canceled, "canceled"},
	} {
		observer := &durationRecord{}
		observeDuration(observer, "ListRooms", time.Now(), test.response, test.err)
		if observer.method != "ListRooms" || observer.outcome != test.outcome {
			t.Fatalf("observed=%+v wanted=%s", observer, test.outcome)
		}
	}
}

func TestUnavailableCausePreservesDeadlineWithoutPrivateErrorText(t *testing.T) {
	err := unavailableCause("participants", context.DeadlineExceeded)
	if !errors.Is(err, context.DeadlineExceeded) || !errors.Is(err, ErrUnavailable) || FailureStage(err) != "participants" || err.Error() != ErrUnavailable.Error() {
		t.Fatalf("classified error=%v stage=%s", err, FailureStage(err))
	}
}
