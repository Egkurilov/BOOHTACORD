package eventhub

import "testing"

func TestSocialHintsRequireNegotiationInLiveAndReplayDelivery(t *testing.T) {
	hub := New(8)
	legacy := hub.SubscribeAccountWithCapabilities("legacy", Event{}, nil)
	aware := hub.SubscribeAccountWithCapabilities("aware", Event{}, []string{"message_social_v1"})
	defer legacy.Close(Event{})
	defer aware.Close(Event{})
	for _, kind := range []string{"message.reactions_updated", "message.pins_updated", "direct_message.reactions_updated"} {
		if legacy.AllowsKind(kind) || !aware.AllowsKind(kind) {
			t.Fatal("replay capability mismatch")
		}
		hub.Publish(Event{Kind: kind})
		select {
		case event := <-aware.Events():
			if event.Kind != kind {
				t.Fatal("wrong hint")
			}
		default:
			t.Fatal("negotiated hint missing")
		}
		select {
		case <-legacy.Events():
			t.Fatal("legacy client got unsupported hint")
		default:
		}
	}
}
