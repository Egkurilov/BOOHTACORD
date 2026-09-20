package searchtextmessages

import (
	"context"
	"errors"
	"strings"
	"testing"
)

const searchChannelID = "22222222-2222-4222-8222-222222222222"

func TestSearchTrimsQueryAndReturnsCursorFromLookahead(t *testing.T) {
	store := &fakeStore{messages: []Message{{ID: "message-3"}, {ID: "message-2"}, {ID: "message-1"}}}
	result, err := New(store).Search(context.Background(), Input{ChannelID: searchChannelID, Query: "  привет  ", Limit: 2})
	if err != nil || len(result.Messages) != 2 || result.NextCursor != "message-2" || store.request.Query != "привет" || store.request.Limit != 2 {
		t.Fatalf("result=%#v request=%#v error=%v", result, store.request, err)
	}
}

func TestSearchRejectsInvalidInputBeforePersistence(t *testing.T) {
	for _, input := range []Input{
		{ChannelID: "bad", Query: "x", Limit: 10},
		{ChannelID: searchChannelID, Query: " ", Limit: 10},
		{ChannelID: searchChannelID, Query: strings.Repeat("я", 257), Limit: 10},
		{ChannelID: searchChannelID, Query: "x", Before: "bad", Limit: 10},
		{ChannelID: searchChannelID, Query: "x", Limit: 0},
		{ChannelID: searchChannelID, Query: "x", Limit: 101},
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
