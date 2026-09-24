package deletedirectmessagerealtime

import (
	"context"
	"time"

	"github.com/google/uuid"
	deletedirectmessage "voice-platform/backend/internal/chat/delete_direct_message"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

type Deleter interface {
	Delete(context.Context, deletedirectmessage.Input) (deletedirectmessage.Result, error)
}
type RecipientResolver interface {
	Resolve(context.Context, string, string) ([]string, error)
}
type Publisher struct {
	deleter    Deleter
	recipients RecipientResolver
	events     *eventhub.Hub
}

func New(deleter Deleter, recipients RecipientResolver, events *eventhub.Hub) Publisher {
	return Publisher{deleter: deleter, recipients: recipients, events: events}
}

func (publisher Publisher) Delete(ctx context.Context, input deletedirectmessage.Input) (deletedirectmessage.Result, error) {
	result, err := publisher.deleter.Delete(ctx, input)
	if err != nil {
		return result, err
	}
	lookupContext, cancel := context.WithTimeout(context.WithoutCancel(ctx), 2*time.Second)
	defer cancel()
	accounts, err := publisher.recipients.Resolve(lookupContext, result.DirectMessageID, input.ActorID)
	if err == nil {
		publisher.events.PublishToAccounts(accounts, eventhub.Event{
			EventID: uuid.NewString(), Kind: "direct_message.message_deleted", OccurredAt: time.Now().UTC(),
			Payload: map[string]any{"direct_message_id": result.DirectMessageID, "message_id": result.ID, "revision": result.Revision},
		})
	}
	return result, nil
}
