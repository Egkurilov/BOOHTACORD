package searchdirectmessagehistory

import (
	"context"
	"errors"
	"testing"
)

const (
	searchActorID         = "11111111-1111-4111-8111-111111111111"
	searchDirectMessageID = "22222222-2222-4222-8222-222222222222"
)

func TestSearchTrimsLookaheadAndReturnsCursor(t *testing.T) {
	store := &fakeStore{messages: []Message{{ID: "message-3"}, {ID: "message-2"}, {ID: "message-1"}}}
	result, err := New(store).Search(context.Background(), Input{ActorID: searchActorID, DirectMessageID: searchDirectMessageID, Query: "  привет  ", Limit: 2})
	if err != nil || len(result.Messages) != 2 || result.NextCursor != "message-2" || store.request.Query != "привет" {
		t.Fatalf("result=%#v request=%#v error=%v", result, store.request, err)
	}
}

func TestSearchRejectsInvalidInputBeforePersistence(t *testing.T) {
	for _, input := range []Input{
		{ActorID: "bad", DirectMessageID: searchDirectMessageID, Query: "x", Limit: 10},
		{ActorID: searchActorID, DirectMessageID: searchDirectMessageID, Query: " ", Limit: 10},
		{ActorID: searchActorID, DirectMessageID: searchDirectMessageID, Query: "x", Limit: 101},
	} {
		store := &fakeStore{}
		_, err := New(store).Search(context.Background(), input)
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

func (store *fakeStore) Search(_ context.Context, request Request) ([]Message, error) {
	store.called, store.request = true, request
	return store.messages, nil
}
