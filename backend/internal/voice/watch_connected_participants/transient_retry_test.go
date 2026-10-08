package watchconnectedparticipants

import (
	"context"
	"errors"
	"net/http/httptest"
	"testing"
	"time"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
)

type transientLister struct{ calls int }

func (l *transientLister) List(context.Context, string) (roster.Result, error) {
	l.calls++
	if l.calls == 1 {
		return roster.Result{}, roster.OperationFailure{Stage: "visibility_initial", Cause: errors.New("db temporarily down")}
	}
	return roster.Result{Channels: []roster.ChannelRoster{{ChannelID: "recovered"}}}, nil
}

type permanentDependencyLister struct{ calls int }

func (l *permanentDependencyLister) List(context.Context, string) (roster.Result, error) {
	l.calls++
	return roster.Result{}, roster.OperationFailure{Stage: "visibility_recheck", Cause: errors.New("temporary dependency outage")}
}

func TestRefreshRecoveryIsBoundedToOneRetry(t *testing.T) {
	lister := &permanentDependencyLister{}
	_, err := loadRefresh(context.Background(), lister, "viewer")
	if err == nil || lister.calls != 2 {
		t.Fatalf("calls=%d err=%v", lister.calls, err)
	}
}

func TestRefreshBackoffStopsOnDeadline(t *testing.T) {
	lister := &permanentDependencyLister{}
	ctx, cancel := context.WithTimeout(context.Background(), 40*time.Millisecond)
	defer cancel()
	_, err := loadRefresh(ctx, lister, "viewer")
	if !errors.Is(err, context.DeadlineExceeded) || lister.calls != 1 {
		t.Fatalf("calls=%d err=%v", lister.calls, err)
	}
}

func TestTransientRefreshRecoversBeforeClosingStream(t *testing.T) {
	lister := &transientLister{}
	writer := httptest.NewRecorder()
	var received roster.Result
	ok := refreshRosterSnapshot(context.Background(), lister, "viewer", func(value roster.Result) bool { received = value; return true }, writer, writer, nil)
	if !ok || lister.calls != 2 || len(received.Channels) != 1 || writer.Body.Len() != 0 {
		t.Fatalf("recovery ok=%v calls=%d received=%v body=%q", ok, lister.calls, received, writer.Body.String())
	}
}

func TestInitialFailureHasRetryAfterOnlyForDependencies(t *testing.T) {
	for _, test := range []struct {
		err    error
		status int
		retry  string
	}{
		{roster.OperationFailure{Stage: "visibility_initial", Cause: errors.New("private db")}, 503, "1"},
		{errors.New("private bug"), 500, ""},
	} {
		writer := httptest.NewRecorder()
		writeInitialFailure(writer, test.err)
		if writer.Code != test.status || writer.Header().Get("Retry-After") != test.retry || writer.Body.String() != "roster unavailable\n" {
			t.Fatalf("status=%d headers=%v body=%s", writer.Code, writer.Header(), writer.Body.String())
		}
	}
}
