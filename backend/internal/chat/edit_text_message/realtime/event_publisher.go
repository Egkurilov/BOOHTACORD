package realtime

import (
	"context"
	"time"

	"github.com/google/uuid"
	edittextmessage "voice-platform/backend/internal/chat/edit_text_message"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

type Editor interface {
	Edit(context.Context, edittextmessage.Input) (edittextmessage.Result, error)
}

type EventPublishingEditor struct {
	editor Editor
	events *eventhub.Hub
}

func New(editor Editor, events *eventhub.Hub) EventPublishingEditor {
	return EventPublishingEditor{editor: editor, events: events}
}

func (publisher EventPublishingEditor) Edit(ctx context.Context, input edittextmessage.Input) (edittextmessage.Result, error) {
	result, err := publisher.editor.Edit(ctx, input)
	if err == nil {
		publisher.events.PublishContext(ctx, eventhub.Event{EventID: uuid.NewString(), Kind: "message.updated", OccurredAt: time.Now().UTC(), Payload: map[string]any{"channel_id": result.ChannelID, "message_id": result.ID}})
	}
	return result, err
}
