package replayeventpostgres

import (
	"github.com/google/uuid"
	"testing"
	"time"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func TestSocialHintsAreExactlyIDsAndDMHintsNeedPrivateRecipients(t *testing.T) {
	for _, kind := range []string{"message.reactions_updated", "message.pins_updated", "direct_message.reactions_updated"} {
		resource := "channel_id"
		var recipients []string
		if kind == "direct_message.reactions_updated" {
			resource = "direct_message_id"
			recipients = []string{uuid.NewString(), uuid.NewString()}
		}
		event := eventhub.Event{EventID: uuid.NewString(), Kind: kind, OccurredAt: time.Now(), Payload: map[string]any{resource: uuid.NewString(), "message_id": uuid.NewString()}}
		if err := validateHint(event, recipients); err != nil {
			t.Fatal("ID-only hint rejected")
		}
		event.Payload["revision"] = 1
		if validateHint(event, recipients) == nil {
			t.Fatal("non-ID metadata accepted")
		}
		delete(event.Payload, "revision")
		event.Payload["body"] = "synthetic"
		if validateHint(event, recipients) == nil {
			t.Fatal("content accepted")
		}
		delete(event.Payload, "body")
		if kind == "direct_message.reactions_updated" && validateHint(event, nil) == nil {
			t.Fatal("private hint can broadcast")
		}
	}
}
