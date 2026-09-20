package createtextmessage

import (
	"context"
	"errors"
	"strings"
	"testing"
)

func TestCreatePersistsIdempotencyAndSameConversationReply(t *testing.T) {
	const messageID = "f1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
	const channelID = "b1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
	const userID = "a1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
	const clientID = "c1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
	const replyID = "d1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
	store := &fakeStore{result: Result{ID: messageID, ChannelID: channelID, AuthorID: userID, ClientMessageID: clientID, Body: "Привет", ReplyToID: replyID}}
	service := New(store)
	service.newID = func() (string, error) { return messageID, nil }
	result, err := service.Create(context.Background(), Input{ActorID: userID, ChannelID: channelID, ClientMessageID: clientID, Body: "Привет", ReplyToID: replyID})
	if err != nil || store.request.ID != messageID || result != store.result {
		t.Fatalf("request = %#v, result = %#v, error = %v", store.request, result, err)
	}
}

func TestCreateRejectsEmptyInvalidOrOversizedBodyBeforePersistence(t *testing.T) {
	for _, body := range []string{"", string([]byte{0xff}), strings.Repeat("я", 8001)} {
		store := &fakeStore{}
		_, err := New(store).Create(context.Background(), Input{ActorID: "a1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610", ChannelID: "b1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610", ClientMessageID: "c1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610", Body: body})
		if !errors.Is(err, ErrInvalidInput) || store.called {
			t.Fatalf("body length = %d, error = %v, called = %v", len(body), err, store.called)
		}
	}
}

type fakeStore struct {
	called  bool
	request Request
	result  Result
}

func (store *fakeStore) Create(_ context.Context, request Request) (Result, error) {
	store.called = true
	store.request = request
	return store.result, nil
}
