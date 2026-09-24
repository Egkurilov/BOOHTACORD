package senddirectmessagerealtime

import (
	"context"
	"errors"
	"testing"

	senddirectmessage "voice-platform/backend/internal/chat/send_direct_message"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

type senderFunc func(context.Context, senddirectmessage.Input) (senddirectmessage.Result, error)

func (send senderFunc) Send(ctx context.Context, input senddirectmessage.Input) (senddirectmessage.Result, error) {
	return send(ctx, input)
}

type resolverFunc func(context.Context, string, string) ([]string, error)

func (resolve resolverFunc) Resolve(ctx context.Context, pairID, actorID string) ([]string, error) {
	return resolve(ctx, pairID, actorID)
}

func TestSuccessfulSendPublishesMinimalPrivateHint(t *testing.T) {
	hub := eventhub.New(1)
	member := hub.Subscribe("member")
	admin := hub.Subscribe("admin")
	defer member.Close()
	defer admin.Close()
	calledAfterSend := false
	publisher := New(senderFunc(func(_ context.Context, _ senddirectmessage.Input) (senddirectmessage.Result, error) {
		calledAfterSend = true
		return senddirectmessage.Result{ID: "message", DirectMessageID: "pair", Body: "secret"}, nil
	}), resolverFunc(func(_ context.Context, pairID, actorID string) ([]string, error) {
		if !calledAfterSend || pairID != "pair" || actorID != "member" {
			t.Fatal("recipient resolution preceded persistence or received wrong IDs")
		}
		return []string{"member"}, nil
	}), hub)
	_, err := publisher.Send(context.Background(), senddirectmessage.Input{ActorID: "member"})
	if err != nil {
		t.Fatal(err)
	}
	select {
	case event := <-member.Events():
		if event.Kind != "direct_message.message_created" || len(event.Payload) != 2 || event.Payload["direct_message_id"] != "pair" || event.Payload["message_id"] != "message" || event.EventID == "" {
			t.Fatalf("private event = %#v", event)
		}
	default:
		t.Fatal("participant did not receive event")
	}
	select {
	case event := <-admin.Events():
		t.Fatalf("administrator received %#v", event)
	default:
	}
}

func TestFailedSendOrRecipientLookupPublishesNothing(t *testing.T) {
	for _, failedStage := range []string{"send", "resolve"} {
		t.Run(failedStage, func(t *testing.T) {
			hub := eventhub.New(1)
			member := hub.Subscribe("member")
			defer member.Close()
			publisher := New(senderFunc(func(_ context.Context, _ senddirectmessage.Input) (senddirectmessage.Result, error) {
				if failedStage == "send" {
					return senddirectmessage.Result{}, errors.New("send failed")
				}
				return senddirectmessage.Result{ID: "message", DirectMessageID: "pair"}, nil
			}), resolverFunc(func(context.Context, string, string) ([]string, error) { return nil, errors.New("lookup failed") }), hub)
			_, err := publisher.Send(context.Background(), senddirectmessage.Input{ActorID: "member"})
			if (failedStage == "send") != (err != nil) {
				t.Fatalf("error = %v", err)
			}
			select {
			case event := <-member.Events():
				t.Fatalf("unexpected event %#v", event)
			default:
			}
		})
	}
}
