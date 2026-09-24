package notifyleaserevocation

import (
	"context"
	"errors"
	"testing"

	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func TestDispatchDoesNotMarkWhenDurableEventWriteFails(t *testing.T) {
	store := &serviceStore{items: []Item{{LeaseID: testLeaseID, UserID: testOwnerID, Reason: "LOGOUT"}}}
	publisher := &fakeDurablePublisher{failure: errors.New("journal unavailable")}
	service := New(store, publisher)
	if _, err := service.Dispatch(context.Background(), 10); err == nil || len(store.marked) != 0 {
		t.Fatalf("failed persistence marked outbox: %#v, %v", store.marked, err)
	}
	publisher.failure = nil
	if count, err := service.Dispatch(context.Background(), 10); err != nil || count != 1 || len(store.marked) != 1 {
		t.Fatalf("retry = %d, %v; marks = %#v", count, err, store.marked)
	}
	if len(publisher.attempts) != 2 || publisher.attempts[0].EventID != publisher.attempts[1].EventID {
		t.Fatalf("retry event IDs = %#v", publisher.attempts)
	}
}

type fakeDurablePublisher struct {
	attempts []eventhub.Event
	failure  error
}

func (publisher *fakeDurablePublisher) PublishToAccountsDurable(_ context.Context, _ []string, event eventhub.Event) error {
	publisher.attempts = append(publisher.attempts, event)
	return publisher.failure
}
