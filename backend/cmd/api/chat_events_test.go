package main

import (
	"context"
	"errors"
	"testing"
	"time"

	createtextmessage "voice-platform/backend/internal/chat/create_text_message"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func TestEventPublishingMessageCreatorPublishesOnlySafeIDsOnSuccess(t *testing.T) {
	hub := eventhub.New(1)
	subscription := hub.Subscribe()
	defer subscription.Close()
	creator := eventPublishingMessageCreator{events: hub, creator: messageCreatorFunc(func(context.Context, createtextmessage.Input) (createtextmessage.Result, error) {
		return createtextmessage.Result{ID: "22222222-2222-4222-8222-222222222222", ChannelID: "11111111-1111-4111-8111-111111111111", Body: "private text"}, nil
	})}
	if _, err := creator.Create(context.Background(), createtextmessage.Input{}); err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	select {
	case event := <-subscription.Events():
		if event.Kind != "message.created" || len(event.Payload) != 2 || event.Payload["channel_id"] != "11111111-1111-4111-8111-111111111111" || event.Payload["message_id"] != "22222222-2222-4222-8222-222222222222" || event.OccurredAt.Location() != time.UTC {
			t.Fatalf("published event = %#v", event)
		}
	case <-time.After(time.Second):
		t.Fatal("message event was not published")
	}
}

func TestEventPublishingMessageCreatorDoesNotPublishOnFailure(t *testing.T) {
	hub := eventhub.New(1)
	subscription := hub.Subscribe()
	defer subscription.Close()
	creator := eventPublishingMessageCreator{events: hub, creator: messageCreatorFunc(func(context.Context, createtextmessage.Input) (createtextmessage.Result, error) {
		return createtextmessage.Result{}, errors.New("failed")
	})}
	if _, err := creator.Create(context.Background(), createtextmessage.Input{}); err == nil {
		t.Fatal("Create() unexpectedly succeeded")
	}
	select {
	case event := <-subscription.Events():
		t.Fatalf("failed create published event %#v", event)
	default:
	}
}

type messageCreatorFunc func(context.Context, createtextmessage.Input) (createtextmessage.Result, error)

func (creator messageCreatorFunc) Create(ctx context.Context, input createtextmessage.Input) (createtextmessage.Result, error) {
	return creator(ctx, input)
}
