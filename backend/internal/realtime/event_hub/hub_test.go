package eventhub

import (
	"testing"
	"time"
)

func TestPublishFansOutToIndependentSubscribers(t *testing.T) {
	hub := New(2)
	first, second := hub.Subscribe(), hub.Subscribe()
	defer first.Close()
	defer second.Close()
	event := Event{EventID: "33333333-3333-4333-8333-333333333333", Kind: "message.created", OccurredAt: time.Unix(1, 0).UTC(), Payload: map[string]any{"channel_id": "11111111-1111-4111-8111-111111111111", "message_id": "22222222-2222-4222-8222-222222222222"}}

	hub.Publish(event)

	if got := <-first.Events(); got.EventID != event.EventID {
		t.Fatalf("first subscriber got %#v", got)
	}
	if got := <-second.Events(); got.EventID != event.EventID {
		t.Fatalf("second subscriber got %#v", got)
	}
}

func TestOverflowSignalsResyncAndCanResume(t *testing.T) {
	hub := New(1)
	subscription := hub.Subscribe()
	defer subscription.Close()
	hub.Publish(Event{EventID: "queued"})
	hub.Publish(Event{EventID: "dropped"})

	select {
	case <-subscription.Overflowed():
	case <-time.After(time.Second):
		t.Fatal("queue overflow did not request resync")
	}
	subscription.AcknowledgeOverflow()
	hub.Publish(Event{EventID: "resumed"})
	select {
	case event := <-subscription.Events():
		if event.EventID != "resumed" {
			t.Fatalf("stale event survived resync: %#v", event)
		}
	case <-time.After(time.Second):
		t.Fatal("delivery did not resume")
	}
}

func TestPresenceCountsIndependentAuthenticatedConnections(t *testing.T) {
	hub := New(2)
	first := hub.Subscribe("account-1")
	second := hub.Subscribe("account-1")
	other := hub.Subscribe("account-2")
	defer second.Close()
	defer other.Close()

	if !hub.IsOnline("account-1") || !hub.IsOnline("account-2") || hub.IsOnline("account-3") {
		t.Fatal("presence did not reflect open account connections")
	}
	first.Close()
	if !hub.IsOnline("account-1") {
		t.Fatal("closing one tab marked another active tab offline")
	}
	second.Close()
	if hub.IsOnline("account-1") {
		t.Fatal("account remained online after its last connection closed")
	}
}

func TestPresenceTransitionEventsAreAtomicWithConnectionCounts(t *testing.T) {
	hub := New(4)
	observer := hub.Subscribe()
	online := Event{EventID: "online", Kind: "presence.changed", Payload: map[string]any{"presence": "online"}}
	offline := Event{EventID: "offline", Kind: "presence.changed", Payload: map[string]any{"presence": "offline"}}
	first := hub.SubscribeAccount("account-1", online)
	second := hub.SubscribeAccount("account-1", online)
	if event := <-observer.Events(); event.EventID != "online" {
		t.Fatalf("first transition = %#v", event)
	}
	if first.Close(offline) || !second.Close(offline) {
		t.Fatal("presence transition did not follow the last active connection")
	}
	if event := <-observer.Events(); event.EventID != "offline" {
		t.Fatalf("last transition = %#v", event)
	}
	observer.Close()
}
