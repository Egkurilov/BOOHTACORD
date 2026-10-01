package realtime

import (
	"context"
	"github.com/google/uuid"
	"time"
	createtextmessage "voice-platform/backend/internal/chat/create_text_message"
	messageapi "voice-platform/backend/internal/chat/create_text_message/api"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func New(creator messageapi.Creator, events *eventhub.Hub) eventPublishingMessageCreator {
	return eventPublishingMessageCreator{creator: creator, events: events}
}

type eventPublishingMessageCreator struct {
	creator messageapi.Creator
	events  *eventhub.Hub
}

func (creator eventPublishingMessageCreator) Create(ctx context.Context, input createtextmessage.Input) (createtextmessage.Result, error) {
	result, err := creator.creator.Create(ctx, input)
	if err == nil {
		creator.events.Publish(eventhub.Event{EventID: uuid.NewString(), Kind: "message.created", OccurredAt: time.Now().UTC(), Payload: map[string]any{"channel_id": result.ChannelID, "message_id": result.ID}})
	}
	return result, err
}
