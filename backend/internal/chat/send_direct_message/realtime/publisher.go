package senddirectmessagerealtime

import (
	"context"
	"time"

	"github.com/google/uuid"
	senddirectmessage "voice-platform/backend/internal/chat/send_direct_message"
	flowstage "voice-platform/backend/internal/observability/flow_stage"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

type Sender interface {
	Send(context.Context, senddirectmessage.Input) (senddirectmessage.Result, error)
}
type RecipientResolver interface {
	Resolve(context.Context, string, string) ([]string, error)
}
type Publisher struct {
	sender     Sender
	recipients RecipientResolver
	events     *eventhub.Hub
}

func New(sender Sender, recipients RecipientResolver, events *eventhub.Hub) Publisher {
	return Publisher{sender: sender, recipients: recipients, events: events}
}

func (publisher Publisher) Send(ctx context.Context, input senddirectmessage.Input) (senddirectmessage.Result, error) {
	result, err := publisher.sender.Send(ctx, input)
	if err != nil {
		return result, err
	}
	flowstage.Mark(ctx, "commit", "success")
	lookupContext, cancel := context.WithTimeout(context.WithoutCancel(ctx), 2*time.Second)
	defer cancel()
	accounts, err := publisher.recipients.Resolve(lookupContext, result.DirectMessageID, input.ActorID)
	if err == nil {
		err = publisher.events.PublishToAccountsContext(lookupContext, accounts, eventhub.Event{
			EventID: uuid.NewString(), Kind: "direct_message.message_created", OccurredAt: time.Now().UTC(),
			Payload: map[string]any{"direct_message_id": result.DirectMessageID, "message_id": result.ID},
		})
	}
	if err != nil {
		flowstage.Mark(ctx, "dispatch", "failed")
	} else {
		flowstage.Mark(ctx, "dispatch", "success")
	}
	return result, nil
}
