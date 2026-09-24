package editdirectmessagerealtime

import (
	"context"
	"errors"
	"testing"

	editdirectmessage "voice-platform/backend/internal/chat/edit_direct_message"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

type editorFunc func(context.Context, editdirectmessage.Input) (editdirectmessage.Result, error)

func (edit editorFunc) Edit(ctx context.Context, input editdirectmessage.Input) (editdirectmessage.Result, error) {
	return edit(ctx, input)
}

type resolverFunc func(context.Context, string, string) ([]string, error)

func (resolve resolverFunc) Resolve(ctx context.Context, pairID, actorID string) ([]string, error) {
	return resolve(ctx, pairID, actorID)
}

func TestSuccessfulEditPublishesRevisionOnlyToPair(t *testing.T) {
	hub := eventhub.New(1)
	member := hub.Subscribe("member")
	outsider := hub.Subscribe("outsider")
	defer member.Close()
	defer outsider.Close()
	committed := false
	publisher := New(editorFunc(func(context.Context, editdirectmessage.Input) (editdirectmessage.Result, error) {
		committed = true
		return editdirectmessage.Result{ID: "message", DirectMessageID: "pair", Revision: 3, Body: "secret"}, nil
	}), resolverFunc(func(_ context.Context, pairID, actorID string) ([]string, error) {
		if !committed || pairID != "pair" || actorID != "member" {
			t.Fatal("invalid recipient lookup")
		}
		return []string{"member"}, nil
	}), hub)
	_, err := publisher.Edit(context.Background(), editdirectmessage.Input{ActorID: "member"})
	if err != nil {
		t.Fatal(err)
	}
	select {
	case event := <-member.Events():
		if event.Kind != "direct_message.message_updated" || len(event.Payload) != 3 || event.Payload["revision"] != 3 || event.Payload["direct_message_id"] != "pair" || event.Payload["message_id"] != "message" {
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

func TestFailedEditDoesNotPublish(t *testing.T) {
	hub := eventhub.New(1)
	member := hub.Subscribe("member")
	defer member.Close()
	publisher := New(editorFunc(func(context.Context, editdirectmessage.Input) (editdirectmessage.Result, error) {
		return editdirectmessage.Result{}, errors.New("conflict")
	}), resolverFunc(func(context.Context, string, string) ([]string, error) {
		t.Fatal("resolved after failure")
		return nil, nil
	}), hub)
	if _, err := publisher.Edit(context.Background(), editdirectmessage.Input{ActorID: "member"}); err == nil {
		t.Fatal("edit succeeded")
	}
	select {
	case event := <-member.Events():
		t.Fatalf("failed edit published %#v", event)
	default:
	}
}
