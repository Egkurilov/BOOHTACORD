package deletedirectmessagerealtime

import (
	"context"
	"errors"
	"testing"

	deletedirectmessage "voice-platform/backend/internal/chat/delete_direct_message"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

type deleterFunc func(context.Context, deletedirectmessage.Input) (deletedirectmessage.Result, error)

func (remove deleterFunc) Delete(ctx context.Context, input deletedirectmessage.Input) (deletedirectmessage.Result, error) {
	return remove(ctx, input)
}

type resolverFunc func(context.Context, string, string) ([]string, error)

func (resolve resolverFunc) Resolve(ctx context.Context, pairID, actorID string) ([]string, error) {
	return resolve(ctx, pairID, actorID)
}

func TestSuccessfulDeletePublishesRevisionOnlyToPair(t *testing.T) {
	hub := eventhub.New(1)
	member := hub.Subscribe("member")
	outsider := hub.Subscribe("outsider")
	defer member.Close()
	defer outsider.Close()
	committed := false
	publisher := New(deleterFunc(func(context.Context, deletedirectmessage.Input) (deletedirectmessage.Result, error) {
		committed = true
		return deletedirectmessage.Result{ID: "message", DirectMessageID: "pair", Revision: 4}, nil
	}), resolverFunc(func(_ context.Context, pairID, actorID string) ([]string, error) {
		if !committed || pairID != "pair" || actorID != "member" {
			t.Fatal("invalid recipient lookup")
		}
		return []string{"member"}, nil
	}), hub)
	_, err := publisher.Delete(context.Background(), deletedirectmessage.Input{ActorID: "member"})
	if err != nil {
		t.Fatal(err)
	}
	select {
	case event := <-member.Events():
		if event.Kind != "direct_message.message_deleted" || len(event.Payload) != 3 || event.Payload["revision"] != 4 || event.Payload["direct_message_id"] != "pair" || event.Payload["message_id"] != "message" {
			t.Fatalf("private event = %#v", event)
		}
	default:
		t.Fatal("participant did not receive event")
	}
	select {
	case event := <-outsider.Events():
		t.Fatalf("outsider received %#v", event)
	default:
	}
}

func TestFailedDeleteDoesNotPublish(t *testing.T) {
	hub := eventhub.New(1)
	member := hub.Subscribe("member")
	defer member.Close()
	publisher := New(deleterFunc(func(context.Context, deletedirectmessage.Input) (deletedirectmessage.Result, error) {
		return deletedirectmessage.Result{}, errors.New("denied")
	}), resolverFunc(func(context.Context, string, string) ([]string, error) {
		t.Fatal("resolved after failure")
		return nil, nil
	}), hub)
	if _, err := publisher.Delete(context.Background(), deletedirectmessage.Input{ActorID: "member"}); err == nil {
		t.Fatal("delete succeeded")
	}
	select {
	case event := <-member.Events():
		t.Fatalf("failed delete published %#v", event)
	default:
	}
}
