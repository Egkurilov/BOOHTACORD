package replayeventpostgres

import (
	"testing"
	"time"

	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func TestValidatePersistedHintRejectsContentAndInvalidIdentifiers(t *testing.T) {
	base := eventhub.Event{
		EventID: "11111111-1111-4111-8111-111111111111", Kind: "direct_message.message_created",
		OccurredAt: time.Now().UTC(),
		Payload: map[string]any{
			"direct_message_id": "22222222-2222-4222-8222-222222222222",
			"message_id":        "33333333-3333-4333-8333-333333333333",
		},
	}
	if err := validateHint(base, []string{"44444444-4444-4444-8444-444444444444"}); err != nil {
		t.Fatalf("valid hint rejected: %v", err)
	}
	for _, mutate := range []func(*eventhub.Event){
		func(event *eventhub.Event) { event.Payload["body"] = "secret" },
		func(event *eventhub.Event) { event.Payload["message_id"] = "not-a-uuid" },
		func(event *eventhub.Event) { event.EventID = "invalid" },
		func(event *eventhub.Event) { event.OccurredAt = time.Time{} },
	} {
		event := base
		event.Payload = map[string]any{}
		for key, value := range base.Payload {
			event.Payload[key] = value
		}
		mutate(&event)
		if err := validateHint(event, []string{"44444444-4444-4444-8444-444444444444"}); err == nil {
			t.Fatalf("unsafe hint accepted: %#v", event)
		}
	}
	if err := validateHint(base, nil); err == nil {
		t.Fatal("private hint without recipients accepted")
	}
}

func TestValidateMemberProfileHintAllowsOnlyMemberIDAndRevision(t *testing.T) {
	event := eventhub.Event{
		EventID: "11111111-1111-4111-8111-111111111111", Kind: "member.profile.updated",
		OccurredAt: time.Now().UTC(), Payload: map[string]any{
			"user_id": "22222222-2222-4222-8222-222222222222", "revision": int64(3),
		},
	}
	if err := validateHint(event, nil); err != nil {
		t.Fatalf("valid profile hint rejected: %v", err)
	}
	event.Payload["display_name"] = "private metadata"
	if err := validateHint(event, nil); err == nil {
		t.Fatal("profile hint accepted display name content")
	}
}
