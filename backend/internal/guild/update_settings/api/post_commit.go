package guildsettingsapi

import (
	"context"
	"github.com/google/uuid"
	"time"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

// The committed revision stays authoritative even when its realtime hint fails.
func (h Handler) publishUpdate(ctx context.Context, revision int64) error {
	if h.Events == nil {
		return eventhub.ErrJournalUnavailable
	}
	publishCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), 5*time.Second)
	defer cancel()
	return h.Events.PublishContext(publishCtx, eventhub.Event{
		EventID: uuid.NewString(), Kind: "guild.profile.updated", OccurredAt: time.Now().UTC(),
		Payload: map[string]any{"revision": revision},
	})
}
