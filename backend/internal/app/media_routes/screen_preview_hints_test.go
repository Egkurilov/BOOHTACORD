package mediaroutes

import (
	"context"
	"testing"

	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

type previewAudienceStub struct {
	accounts []string
	err      error
}

func (stub previewAudienceStub) ActiveViewers(context.Context, string) ([]string, error) {
	return stub.accounts, stub.err
}

func TestScreenPreviewHintsAreTargetedMetadataOnlyAndCapabilityGated(t *testing.T) {
	hub := eventhub.New(4)
	viewer := hub.SubscribeAccountWithCapabilities("viewer", eventhub.Event{}, []string{"screen_previews_v1"})
	legacy := hub.Subscribe("legacy")
	defer viewer.Close()
	defer legacy.Close()
	hints := screenPreviewHints{authorizer: previewAudienceStub{accounts: []string{"viewer"}}, events: hub}
	hints.Updated(context.Background(), "lease", "generation", 3)
	event := <-viewer.Events()
	if event.Kind != "screen_preview.updated" || event.Payload["lease_id"] != "lease" || event.Payload["generation_id"] != "generation" || event.Payload["revision"] != uint64(3) || len(event.Payload) != 3 {
		t.Fatalf("preview hint leaked or malformed: %#v", event)
	}
	select {
	case <-legacy.Events():
		t.Fatal("legacy client received unsupported preview event")
	default:
	}
}

func TestScreenPreviewInvalidationTargetsOnlyCurrentAudience(t *testing.T) {
	hub := eventhub.New(2)
	viewer := hub.SubscribeAccountWithCapabilities("viewer", eventhub.Event{}, []string{"screen_previews_v1"})
	defer viewer.Close()
	screenPreviewHints{authorizer: previewAudienceStub{accounts: []string{"viewer"}}, events: hub}.Invalidated(context.Background(), "lease", "generation")
	event := <-viewer.Events()
	if event.Kind != "screen_preview.invalidated" || len(event.Payload) != 2 || event.Payload["generation_id"] != "generation" {
		t.Fatalf("invalidation hint = %#v", event)
	}
}
