package replayeventpostgres

import (
	"testing"
	"time"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func TestGuildProfileHintHasOnlyPositiveRevision(t *testing.T) {
	event := eventhub.Event{EventID: "11111111-1111-4111-8111-111111111111", OccurredAt: time.Now(), Kind: "guild.profile.updated", Payload: map[string]any{"revision": int64(2)}}
	if err := validateHint(event, nil); err != nil {
		t.Fatal("valid profile revision rejected")
	}
	event.Payload["name"] = "private guild"
	if err := validateHint(event, nil); err == nil {
		t.Fatal("guild name in durable hint")
	}
	event.Payload = map[string]any{"revision": float64(1.5)}
	if err := validateHint(event, nil); err == nil {
		t.Fatal("fractional revision accepted")
	}
}
