package advancetextchannelreadcursor

import (
	"context"
	"errors"
	"testing"
	"time"
)

const validID = "11111111-1111-4111-8111-111111111111"

func TestAdvancePassesOnlyValidatedCallerCursor(t *testing.T) {
	store := &fakeStore{result: Result{MessageID: validID, MessageCreatedAt: time.Unix(1, 0)}}
	result, err := New(store).Advance(context.Background(), Input{ActorID: validID, ChannelID: validID, MessageID: validID})
	if err != nil || result.MessageID != validID || store.request.ActorID != validID {
		t.Fatalf("result=%#v request=%#v error=%v", result, store.request, err)
	}
}

func TestAdvanceRejectsInvalidInputBeforePersistence(t *testing.T) {
	store := &fakeStore{}
	_, err := New(store).Advance(context.Background(), Input{ActorID: "invalid", ChannelID: validID, MessageID: validID})
	if !errors.Is(err, ErrInvalidInput) || store.called {
		t.Fatalf("error=%v called=%v", err, store.called)
	}
}

func TestAdvancePreservesUnavailable(t *testing.T) {
	_, err := New(&fakeStore{err: ErrChannelUnavailable}).Advance(context.Background(), Input{ActorID: validID, ChannelID: validID, MessageID: validID})
	if !errors.Is(err, ErrChannelUnavailable) {
		t.Fatalf("error=%v", err)
	}
}

type fakeStore struct {
	called  bool
	request Request
	result  Result
	err     error
}

func (store *fakeStore) Advance(_ context.Context, request Request) (Result, error) {
	store.called, store.request = true, request
	return store.result, store.err
}
