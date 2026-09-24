package realtime

import (
	"context"
	"errors"
	"testing"
	"time"

	deletetextmessage "voice-platform/backend/internal/chat/delete_text_message"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func TestEventPublishingDeleterPublishesOnlyIDsAfterSuccess(t *testing.T) {
	hub := eventhub.New(1)
	subscription := hub.Subscribe()
	defer subscription.Close()
	deleter := New(deleterFunc(func(context.Context, deletetextmessage.Input) (deletetextmessage.Result, error) {
		return deletetextmessage.Result{ID: "22222222-2222-4222-8222-222222222222", ChannelID: "11111111-1111-4111-8111-111111111111"}, nil
	}), hub)
	if _, err := deleter.Delete(context.Background(), deletetextmessage.Input{}); err != nil {
		t.Fatalf("Delete() error = %v", err)
	}
	select {
	case event := <-subscription.Events():
		if event.Kind != "message.deleted" || len(event.Payload) != 2 || event.Payload["channel_id"] != "11111111-1111-4111-8111-111111111111" || event.Payload["message_id"] != "22222222-2222-4222-8222-222222222222" || event.OccurredAt.Location() != time.UTC {
			t.Fatalf("published event = %#v", event)
		}
	case <-time.After(time.Second):
		t.Fatal("message deletion event was not published")
	}
}

func TestEventPublishingDeleterDoesNotPublishOnFailure(t *testing.T) {
	hub := eventhub.New(1)
	subscription := hub.Subscribe()
	defer subscription.Close()
	deleter := New(deleterFunc(func(context.Context, deletetextmessage.Input) (deletetextmessage.Result, error) {
		return deletetextmessage.Result{}, errors.New("failed")
	}), hub)
	if _, err := deleter.Delete(context.Background(), deletetextmessage.Input{}); err == nil {
		t.Fatal("Delete() unexpectedly succeeded")
	}
	select {
	case event := <-subscription.Events():
		t.Fatalf("failed delete published event %#v", event)
	default:
	}
}

type deleterFunc func(context.Context, deletetextmessage.Input) (deletetextmessage.Result, error)

func (deleter deleterFunc) Delete(ctx context.Context, input deletetextmessage.Input) (deletetextmessage.Result, error) {
	return deleter(ctx, input)
}
