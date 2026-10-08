package listconnectedparticipants

import (
	"context"
	"errors"
	"testing"
	"time"

	snapshotlivekitpresence "voice-platform/backend/internal/media/snapshot_livekit_presence"
)

type cancelPresence struct{}

func (cancelPresence) SnapshotRooms(ctx context.Context, _ []string) (map[string][]snapshotlivekitpresence.ConnectedLease, error) {
	return nil, ctx.Err()
}

func TestListClassifiesSnapshotDeadlineAsFailure(t *testing.T) {
	secondRoom := "66666666-6666-4666-8666-666666666666"
	ctx, cancel := context.WithDeadline(context.Background(), time.Now().Add(-time.Second))
	defer cancel()
	observer := &snapshotObserver{}
	service := New(&repositoryStub{channels: []Channel{{ID: channelID}, {ID: secondRoom}}}, cancelPresence{}, observer)
	_, err := service.List(ctx, actorID)
	if !errors.Is(err, ErrPresenceUnavailable) {
		t.Fatalf("deadline snapshot error = %v", err)
	}
	if !observer.failed || len(observer.failures) != 1 || observer.failures[0] != "presence_snapshot_timeout" {
		t.Fatalf("deadline failure was not classified: %+v", observer)
	}
}

func TestListDoesNotClassifyCallerCancellationAsDependencyFailure(t *testing.T) {
	secondRoom := "66666666-6666-4666-8666-666666666666"
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	observer := &snapshotObserver{}
	service := New(&repositoryStub{channels: []Channel{{ID: channelID}, {ID: secondRoom}}}, cancelPresence{}, observer)
	_, err := service.List(ctx, actorID)
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("canceled snapshot error = %v", err)
	}
	if observer.failed || len(observer.failures) != 0 {
		t.Fatalf("caller cancellation counted as dependency failure: %+v", observer)
	}
}
