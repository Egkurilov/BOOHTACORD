package screenpreviewapp

import (
	"context"
	"time"

	"github.com/google/uuid"
	screenpreview "voice-platform/backend/internal/media/screen_preview"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

type previewAudience interface {
	ActiveViewers(context.Context, string) ([]string, error)
}

type screenPreviewHints struct {
	authorizer previewAudience
	events     *eventhub.Hub
}

func (hints screenPreviewHints) Updated(ctx context.Context, leaseID, generationID string, revision uint64) {
	hints.publish(ctx, "screen_preview.updated", map[string]any{
		"lease_id": leaseID, "generation_id": generationID, "revision": revision,
	})
}

func (hints screenPreviewHints) Invalidated(ctx context.Context, leaseID, generationID string) {
	hints.publish(ctx, "screen_preview.invalidated", map[string]any{
		"lease_id": leaseID, "generation_id": generationID,
	})
}

func (hints screenPreviewHints) publish(ctx context.Context, kind string, payload map[string]any) {
	if hints.events == nil || hints.authorizer == nil {
		return
	}
	leaseID, ok := payload["lease_id"].(string)
	if !ok {
		return
	}
	accounts, err := hints.authorizer.ActiveViewers(ctx, leaseID)
	if err != nil || len(accounts) == 0 {
		return
	}
	_ = hints.events.PublishToAccountsContext(ctx, accounts, eventhub.Event{
		EventID: uuid.NewString(), Kind: kind, OccurredAt: time.Now().UTC(), Payload: payload,
	})
}

var _ screenpreview.HintPublisher = screenPreviewHints{}
