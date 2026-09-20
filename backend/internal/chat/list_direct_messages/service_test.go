package listdirectmessages

import (
	"context"
	"errors"
	"testing"
)

const listActorID = "11111111-1111-4111-8111-111111111111"

func TestListReturnsCallerDirectMessages(t *testing.T) {
	store := &fakeStore{directMessages: []DirectMessage{{ID: "22222222-2222-4222-8222-222222222222", OtherParticipantID: "33333333-3333-4333-8333-333333333333", OtherParticipantDisplayName: "Собеседник"}}}
	result, err := New(store).List(context.Background(), Input{ActorID: listActorID})
	if err != nil || len(result.DirectMessages) != 1 || result.DirectMessages[0].OtherParticipantDisplayName != "Собеседник" || store.request.ActorID != listActorID {
		t.Fatalf("result=%#v request=%#v error=%v", result, store.request, err)
	}
}

func TestListRejectsInvalidCallerBeforePersistence(t *testing.T) {
	store := &fakeStore{}
	_, err := New(store).List(context.Background(), Input{ActorID: "not-a-uuid"})
	if !errors.Is(err, ErrInvalidInput) || store.called {
		t.Fatalf("error=%v called=%v", err, store.called)
	}
}

type fakeStore struct {
	called         bool
	request        Request
	directMessages []DirectMessage
}

func (store *fakeStore) List(_ context.Context, request Request) ([]DirectMessage, error) {
	store.called, store.request = true, request
	return store.directMessages, nil
}
