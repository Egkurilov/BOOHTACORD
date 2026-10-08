package watchconnectedparticipants

import (
	"context"
	"net/http/httptest"
	"testing"

	roster "voice-platform/backend/internal/voice/list_connected_participants"
)

type canceledLister struct{}

func (canceledLister) List(context.Context, string) (roster.Result, error) {
	return roster.Result{}, context.Canceled
}

func TestCanceledRefreshClosesWithoutUnavailableEventOrFailureMetric(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	writer := httptest.NewRecorder()
	observer := &failureStageObserver{stages: make(chan string, 1)}
	write := func(roster.Result) bool { return true }
	if refreshRosterSnapshot(ctx, canceledLister{}, "viewer", write, writer, writer, observer) {
		t.Fatal("canceled snapshot kept the stream open")
	}
	if writer.Body.Len() != 0 {
		t.Fatalf("canceled snapshot emitted event: %q", writer.Body.String())
	}
	select {
	case stage := <-observer.stages:
		t.Fatalf("caller cancellation emitted failure stage %q", stage)
	default:
	}
}
