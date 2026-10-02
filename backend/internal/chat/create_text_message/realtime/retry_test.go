package realtime

import (
	"context"
	"testing"

	createtextmessage "voice-platform/backend/internal/chat/create_text_message"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

// A successful idempotent retry still emits a fresh safe invalidation hint.
// Consumers deduplicate message IDs; changing this behavior requires a separate contract decision.
func TestSuccessfulRetryPreservesExistingHintSemantics(t *testing.T) {
	hub := eventhub.New(2)
	subscription := hub.Subscribe()
	defer subscription.Close()
	result := createtextmessage.Result{ID: "message", ChannelID: "channel", Body: "private"}
	creator := New(messageCreatorFunc(func(context.Context, createtextmessage.Input) (createtextmessage.Result, error) {
		return result, nil
	}), hub)
	for range 2 {
		actual, err := creator.Create(context.Background(), createtextmessage.Input{ClientMessageID: "same-id"})
		if err != nil || actual.ID != result.ID {
			t.Fatal("retry result changed")
		}
	}
	first, second := <-subscription.Events(), <-subscription.Events()
	if first.EventID == second.EventID || first.Payload["message_id"] != second.Payload["message_id"] {
		t.Fatal("successful retry hint semantics changed")
	}
}
