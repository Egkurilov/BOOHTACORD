package searchmessages

import (
	"context"
	"errors"
	"testing"
	"time"
)

const (
	actorID         = "11111111-1111-4111-8111-111111111111"
	channelID       = "22222222-2222-4222-8222-222222222222"
	directMessageID = "33333333-3333-4333-8333-333333333333"
)

func TestSearchCreatesMixedConversationCursor(t *testing.T) {
	createdAt := time.Date(2026, 9, 24, 12, 30, 0, 0, time.UTC)
	store := &searchStore{messages: []Message{
		{ID: "44444444-4444-4444-8444-444444444444", Kind: KindChannel, ChannelID: channelID, CreatedAt: createdAt, Revision: 1},
		{ID: "55555555-5555-4555-8555-555555555555", Kind: KindDirectMessage, DirectMessageID: directMessageID, CreatedAt: createdAt.Add(-time.Minute), Revision: 1},
		{ID: "66666666-6666-4666-8666-666666666666", Kind: KindChannel, ChannelID: channelID, CreatedAt: createdAt.Add(-2 * time.Minute), Revision: 1},
	}}
	service := New(store)
	result, err := service.Search(context.Background(), Input{ActorID: actorID, Query: " игра ", Limit: 2})
	if err != nil || len(result.Messages) != 2 || result.NextCursor == "" || store.request.Query != "игра" {
		t.Fatalf("result=%+v request=%+v err=%v", result, store.request, err)
	}

	store.messages = nil
	_, err = service.Search(context.Background(), Input{ActorID: actorID, Query: "игра", Before: result.NextCursor, Limit: 2})
	if err != nil || store.request.Before == nil || store.request.Before.ID != result.Messages[1].ID || !store.request.Before.CreatedAt.Equal(createdAt.Add(-time.Minute)) {
		t.Fatalf("cursor request=%+v err=%v", store.request, err)
	}
}

func TestSearchRejectsInvalidInputBeforeStore(t *testing.T) {
	store := &searchStore{}
	service := New(store)
	invalid := []Input{
		{ActorID: "bad", Query: "x", Limit: 10},
		{ActorID: actorID, ChannelID: channelID, DirectMessageID: directMessageID, Query: "x", Limit: 10},
		{ActorID: actorID, DirectMessageID: "bad", Query: "x", Limit: 10},
		{ActorID: actorID, Query: " ", Limit: 10},
		{ActorID: actorID, Query: "x", Limit: 101},
		{ActorID: actorID, Query: "x", Before: "not-a-cursor", Limit: 10},
	}
	for _, input := range invalid {
		if _, err := service.Search(context.Background(), input); !errors.Is(err, ErrInvalidInput) || store.called {
			t.Fatalf("input=%+v err=%v called=%v", input, err, store.called)
		}
	}
}

type searchStore struct {
	messages []Message
	request  Request
	called   bool
}

func (store *searchStore) Search(_ context.Context, request Request) ([]Message, error) {
	store.called = true
	store.request = request
	return store.messages, nil
}
