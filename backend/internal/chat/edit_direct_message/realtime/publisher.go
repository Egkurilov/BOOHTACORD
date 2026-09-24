package editdirectmessagerealtime

import (
	"context"
	"time"

	"github.com/google/uuid"
	editdirectmessage "voice-platform/backend/internal/chat/edit_direct_message"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

type Editor interface {
	Edit(context.Context, editdirectmessage.Input) (editdirectmessage.Result, error)
}
type RecipientResolver interface {
	Resolve(context.Context, string, string) ([]string, error)
}
type Publisher struct {
	editor     Editor
	recipients RecipientResolver
	events     *eventhub.Hub
}

func New(editor Editor, recipients RecipientResolver, events *eventhub.Hub) Publisher {
	return Publisher{editor: editor, recipients: recipients, events: events}
}

func (publisher Publisher) Edit(ctx context.Context, input editdirectmessage.Input) (editdirectmessage.Result, error) {
	result, err := publisher.editor.Edit(ctx, input)
	if err != nil {
		return result, err
	}
	lookupContext, cancel := context.WithTimeout(context.WithoutCancel(ctx), 2*time.Second)
	defer cancel()
	accounts, err := publisher.recipients.Resolve(lookupContext, result.DirectMessageID, input.ActorID)
	if err == nil {
		publisher.events.PublishToAccounts(accounts, eventhub.Event{
			EventID: uuid.NewString(), Kind: "direct_message.message_updated", OccurredAt: time.Now().UTC(),
			Payload: map[string]any{"direct_message_id": result.DirectMessageID, "message_id": result.ID, "revision": result.Revision},
		})
	}
	return result, nil
}
