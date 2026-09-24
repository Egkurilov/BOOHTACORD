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
