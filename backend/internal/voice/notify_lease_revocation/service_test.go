package notifyleaserevocation

import (
	"context"
	"errors"
	"testing"
	"time"

	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

const testLeaseID = "11111111-1111-4111-8111-111111111111"
const testOwnerID = "22222222-2222-4222-8222-222222222222"

func TestDispatchPublishesOnlyOwnLeaseAndReason(t *testing.T) {
	for _, reason := range []string{"TRANSFER", "KICK", "CHANNEL_CLOSED", "SESSION_REVOKED", "BANNED", "LOGOUT", "VOLUNTARY_LEAVE"} {
		t.Run(reason, func(t *testing.T) {
			hub := eventhub.New(2)
			owner := hub.Subscribe(testOwnerID)
			outsider := hub.Subscribe("33333333-3333-4333-8333-333333333333")
			administrator := hub.Subscribe("44444444-4444-4444-8444-444444444444")
			store := &serviceStore{items: []Item{{LeaseID: testLeaseID, UserID: testOwnerID, Reason: reason, RequestedAt: time.Unix(100, 0).UTC()}}}
			if n, err := New(store, testDurableHub{hub}).Dispatch(context.Background(), 10); err != nil || n != 1 {
				t.Fatalf("dispatch count = %d, error = %v", n, err)
			}
			select {
			case event := <-owner.Events():
				if event.Kind != "voice.lease_revoked" || event.Payload["lease_id"] != testLeaseID || event.Payload["reason"] != reason || len(event.Payload) != 2 || event.OccurredAt != store.items[0].RequestedAt {
					t.Fatalf("private event = %#v", event)
				}
			default:
				t.Fatal("owner did not receive revocation")
			}
			for _, subscription := range []*eventhub.Subscription{outsider, administrator} {
				select {
				case event := <-subscription.Events():
					t.Fatalf("unrelated subscriber received %#v", event)
				default:
				}
			}
			if len(store.marked) != 1 {
				t.Fatalf("marked = %#v", store.marked)
			}
		})
	}
}

func TestDispatchRetryKeepsStableEventID(t *testing.T) {
	hub := eventhub.New(2)
	owner := hub.Subscribe(testOwnerID)
	store := &serviceStore{items: []Item{{LeaseID: testLeaseID, UserID: testOwnerID, Reason: "KICK"}}, markError: errors.New("database unavailable")}
	service := New(store, testDurableHub{hub})
	if _, err := service.Dispatch(context.Background(), 10); err == nil {
		t.Fatal("expected mark failure")
	}
	first := <-owner.Events()
	store.markError = nil
	if n, err := service.Dispatch(context.Background(), 10); err != nil || n != 1 {
		t.Fatalf("retry count = %d, error = %v", n, err)
	}
	second := <-owner.Events()
	if first.EventID == "" || first.EventID != second.EventID {
		t.Fatalf("unstable event IDs: %q and %q", first.EventID, second.EventID)
	}
}

func TestDispatchNeverShowsAnotherOwnersLease(t *testing.T) {
	hub := eventhub.New(2)
	firstOwner := hub.Subscribe(testOwnerID)
	secondOwner := hub.Subscribe("33333333-3333-4333-8333-333333333333")
	otherLeaseID := "55555555-5555-4555-8555-555555555555"
	store := &serviceStore{items: []Item{
		{LeaseID: testLeaseID, UserID: testOwnerID, Reason: "TRANSFER"},
		{LeaseID: otherLeaseID, UserID: "33333333-3333-4333-8333-333333333333", Reason: "KICK"},
	}}
	if n, err := New(store, testDurableHub{hub}).Dispatch(context.Background(), 10); err != nil || n != 2 {
		t.Fatalf("dispatch = %d, %v", n, err)
	}
	if event := <-firstOwner.Events(); event.Payload["lease_id"] != testLeaseID {
		t.Fatalf("first owner received %#v", event)
	}
	if event := <-secondOwner.Events(); event.Payload["lease_id"] != otherLeaseID {
		t.Fatalf("second owner received %#v", event)
	}
	for _, subscription := range []*eventhub.Subscription{firstOwner, secondOwner} {
		select {
		case event := <-subscription.Events():
			t.Fatalf("owner received foreign or duplicate event %#v", event)
		default:
		}
	}
}

type testDurableHub struct{ hub *eventhub.Hub }

func (publisher testDurableHub) PublishToAccountsDurable(_ context.Context, accounts []string, event eventhub.Event) error {
	publisher.hub.PublishToAccounts(accounts, event)
	return nil
}

type serviceStore struct {
	items     []Item
	marked    []Item
	markError error
}

func (store *serviceStore) Claim(context.Context, int) ([]Item, error) { return store.items, nil }
func (store *serviceStore) MarkEmitted(_ context.Context, item Item) error {
	if store.markError != nil {
		return store.markError
	}
	store.marked = append(store.marked, item)
	return nil
}
