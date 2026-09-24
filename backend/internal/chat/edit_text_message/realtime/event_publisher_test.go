package realtime

import (
	"context"
	"testing"
	"time"

	edittextmessage "voice-platform/backend/internal/chat/edit_text_message"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func TestEventPublishingEditorPublishesOnlyIDsAfterSuccess(t *testing.T) {
	hub := eventhub.New(1)
	subscription := hub.Subscribe()
	defer subscription.Close()
	editor := New(editorFunc(func(context.Context, edittextmessage.Input) (edittextmessage.Result, error) {
		return edittextmessage.Result{ID: "22222222-2222-4222-8222-222222222222", ChannelID: "11111111-1111-4111-8111-111111111111", Body: "private text"}, nil
	}), hub)
	if _, err := editor.Edit(context.Background(), edittextmessage.Input{}); err != nil {
		t.Fatalf("Edit() error = %v", err)
	}
	select {
	case event := <-subscription.Events():
		if event.Kind != "message.updated" || len(event.Payload) != 2 || event.Payload["channel_id"] != "11111111-1111-4111-8111-111111111111" || event.Payload["message_id"] != "22222222-2222-4222-8222-222222222222" || event.OccurredAt.Location() != time.UTC {
			t.Fatalf("published event = %#v", event)
		}
	case <-time.After(time.Second):
		t.Fatal("message edit event was not published")
	}
}

func TestEventPublishingEditorDoesNotPublishConflict(t *testing.T) {
	hub := eventhub.New(1)
	subscription := hub.Subscribe()
	defer subscription.Close()
	editor := New(editorFunc(func(context.Context, edittextmessage.Input) (edittextmessage.Result, error) {
		return edittextmessage.Result{}, edittextmessage.ErrConflict
	}), hub)
	if _, err := editor.Edit(context.Background(), edittextmessage.Input{}); err == nil {
		t.Fatal("Edit() unexpectedly succeeded")
	}
	select {
	case event := <-subscription.Events():
		t.Fatalf("conflicting edit published event %#v", event)
	default:
	}
}

type editorFunc func(context.Context, edittextmessage.Input) (edittextmessage.Result, error)

func (editor editorFunc) Edit(ctx context.Context, input edittextmessage.Input) (edittextmessage.Result, error) {
	return editor(ctx, input)
}
