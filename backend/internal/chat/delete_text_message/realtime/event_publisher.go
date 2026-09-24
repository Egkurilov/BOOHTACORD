package realtime

import (
	"context"
	"time"

	"github.com/google/uuid"
	deletetextmessage "voice-platform/backend/internal/chat/delete_text_message"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

type Deleter interface {
	Delete(context.Context, deletetextmessage.Input) (deletetextmessage.Result, error)
}

type EventPublishingDeleter struct {
	deleter Deleter
	events  *eventhub.Hub
}

func New(deleter Deleter, events *eventhub.Hub) EventPublishingDeleter {
	return EventPublishingDeleter{deleter: deleter, events: events}
}

func (publisher EventPublishingDeleter) Delete(ctx context.Context, input deletetextmessage.Input) (deletetextmessage.Result, error) {
	result, err := publisher.deleter.Delete(ctx, input)
	if err == nil {
		publisher.events.Publish(eventhub.Event{EventID: uuid.NewString(), Kind: "message.deleted", OccurredAt: time.Now().UTC(), Payload: map[string]any{"channel_id": result.ChannelID, "message_id": result.ID}})
	}
	return result, err
}
