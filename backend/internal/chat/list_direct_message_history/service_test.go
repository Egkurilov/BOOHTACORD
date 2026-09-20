package listdirectmessagehistory

import (
	"context"
	"errors"
	"testing"
)

const (
	historyActorID         = "11111111-1111-4111-8111-111111111111"
	historyDirectMessageID = "22222222-2222-4222-8222-222222222222"
)

func TestListTrimsLookaheadAndReturnsCursor(t *testing.T) {
	store := &fakeStore{messages: []Message{{ID: "message-3"}, {ID: "message-2"}, {ID: "message-1"}}}
	result, err := New(store).List(context.Background(), Input{ActorID: historyActorID, DirectMessageID: historyDirectMessageID, Limit: 2})
	if err != nil || len(result.Messages) != 2 || result.NextCursor != "message-2" || store.request.Limit != 2 {
		t.Fatalf("result=%#v request=%#v error=%v", result, store.request, err)
	}
}

func TestListRejectsInvalidCallerCursorAndLimitBeforePersistence(t *testing.T) {
	for _, input := range []Input{
		{ActorID: "not-a-uuid", DirectMessageID: historyDirectMessageID, Limit: 10},
		{ActorID: historyActorID, DirectMessageID: historyDirectMessageID, Before: "not-a-uuid", Limit: 10},
		{ActorID: historyActorID, DirectMessageID: historyDirectMessageID, Limit: 101},
	} {
		store := &fakeStore{}
		_, err := New(store).List(context.Background(), input)
		if !errors.Is(err, ErrInvalidInput) || store.called {
			t.Fatalf("input=%#v error=%v called=%v", input, err, store.called)
		}
	}
}

type fakeStore struct {
	called   bool
	request  Request
	messages []Message
}

func (store *fakeStore) List(_ context.Context, request Request) ([]Message, error) {
	store.called, store.request = true, request
	return store.messages, nil
}
