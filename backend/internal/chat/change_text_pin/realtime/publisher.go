package changetextpinrealtime

import (
	"context"
	"github.com/google/uuid"
	"time"
	action "voice-platform/backend/internal/chat/change_text_pin"
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
	_ = p.hub.PublishContext(publication, eventhub.Event{EventID: uuid.NewString(), Kind: "message.pins_updated", OccurredAt: time.Now().UTC(), Payload: map[string]any{"channel_id": in.ChannelID, "message_id": in.MessageID}})
	return result, nil
}
