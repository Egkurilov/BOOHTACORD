package changemessagereactionrealtime

import (
	"context"
	"github.com/google/uuid"
	"time"
	action "voice-platform/backend/internal/chat/change_message_reaction"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

type Changer interface {
	Set(context.Context, action.Input) (action.Result, error)
}
type Publisher struct {
	inner Changer
	hub   *eventhub.Hub
}

func New(inner Changer, hub *eventhub.Hub) Publisher { return Publisher{inner, hub} }
func (p Publisher) Set(ctx context.Context, in action.Input) (action.Result, error) {
	result, err := p.inner.Set(ctx, in)
	if err != nil || !result.Changed || p.hub == nil {
		return result, err
	}
	publication, cancel := context.WithTimeout(context.WithoutCancel(ctx), 2*time.Second)
	defer cancel()
	event := eventhub.Event{EventID: uuid.NewString(), Kind: "message.reactions_updated", OccurredAt: time.Now().UTC(), Payload: map[string]any{"channel_id": in.ConversationID, "message_id": in.MessageID}}
	if in.Direct {
		event.Kind = "direct_message.reactions_updated"
		event.Payload = map[string]any{"direct_message_id": in.ConversationID, "message_id": in.MessageID}
		_ = p.hub.PublishToAccountsContext(publication, result.Recipients, event)
	} else {
		_ = p.hub.PublishContext(publication, event)
	}
	return result, nil
}
