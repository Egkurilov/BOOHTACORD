package changemessagereactionrealtime

import (
	"context"
	"errors"
	"testing"
	action "voice-platform/backend/internal/chat/change_message_reaction"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

type changerFunc func(context.Context, action.Input) (action.Result, error)

func (f changerFunc) Set(c context.Context, in action.Input) (action.Result, error) { return f(c, in) }

type journal struct {
	events     []eventhub.Event
	recipients [][]string
}

func (j *journal) Append(_ context.Context, event eventhub.Event, to []string, _ string) error {
	j.events = append(j.events, event)
	j.recipients = append(j.recipients, to)
	return nil
}
func (*journal) Replay(context.Context, string, string, string, int) ([]eventhub.Event, error) {
	return nil, nil
}
func (*journal) Authorize(context.Context, string, eventhub.Event) (bool, error) { return true, nil }
func TestPrivatePublicationContainsOnlyIDsAndTargetsExactlyParticipants(t *testing.T) {
	hub := eventhub.New(4)
	j := &journal{}
	hub.SetJournal(j)
	one := hub.SubscribeAccountWithCapabilities("one", eventhub.Event{}, []string{"message_social_v1"})
	defer one.Close()
	two := hub.SubscribeAccountWithCapabilities("two", eventhub.Event{}, []string{"message_social_v1"})
	defer two.Close()
	admin := hub.SubscribeAccountWithCapabilities("admin", eventhub.Event{}, []string{"message_social_v1"})
	defer admin.Close()
	p := New(changerFunc(func(context.Context, action.Input) (action.Result, error) {
		return action.Result{Changed: true, Recipients: []string{"one", "two"}}, nil
	}), hub)
	_, err := p.Set(t.Context(), action.Input{Direct: true, ConversationID: "pair", MessageID: "message", Emoji: "👍", Present: true})
	if err != nil || len(j.events) != 1 || len(j.recipients[0]) != 2 {
		t.Fatal("missing committed targeted hint")
	}
	if j.events[0].Kind != "direct_message.reactions_updated" || len(j.events[0].Payload) != 2 || j.events[0].Payload["direct_message_id"] != "pair" || j.events[0].Payload["message_id"] != "message" {
		t.Fatal("hint contains unexpected metadata")
	}
	for _, s := range []*eventhub.Subscription{one, two} {
		select {
		case <-s.Events():
		default:
			t.Fatal("participant omitted")
		}
	}
	select {
	case <-admin.Events():
		t.Fatal("DM hint leaked to admin")
	default:
	}
}
func TestUnchangedAndRejectedCommandsPublishNothing(t *testing.T) {
	for _, err := range []error{nil, errors.New("denied")} {
		hub := eventhub.New(4)
		j := &journal{}
		hub.SetJournal(j)
		p := New(changerFunc(func(context.Context, action.Input) (action.Result, error) { return action.Result{}, err }), hub)
		_, got := p.Set(t.Context(), action.Input{})
		if got != err || len(j.events) != 0 {
			t.Fatal("uncommitted change published")
		}
	}
}
