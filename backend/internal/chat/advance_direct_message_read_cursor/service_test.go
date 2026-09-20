package advancedirectmessagereadcursor

import (
	"context"
	"errors"
	"testing"
	"time"
)

const validID = "11111111-1111-4111-8111-111111111111"

func TestAdvancePersistsParticipantCursor(t *testing.T) {
	store := &fakeStore{result: Result{MessageID: validID, MessageCreatedAt: time.Unix(1, 0)}}
	result, err := New(store).Advance(context.Background(), Input{ActorID: validID, DirectMessageID: validID, MessageID: validID})
	if err != nil || result.MessageID != validID || store.request.ActorID != validID {
		t.Fatalf("result=%#v request=%#v error=%v", result, store.request, err)
	}
}

func TestAdvanceRejectsInvalidInputBeforePersistence(t *testing.T) {
	store := &fakeStore{}
	_, err := New(store).Advance(context.Background(), Input{ActorID: "not-a-uuid", DirectMessageID: validID, MessageID: validID})
	if !errors.Is(err, ErrInvalidInput) || store.called {
		t.Fatalf("error=%v called=%v", err, store.called)
	}
}

func TestAdvancePreservesUnavailableResult(t *testing.T) {
	_, err := New(&fakeStore{err: ErrDirectMessageUnavailable}).Advance(context.Background(), Input{ActorID: validID, DirectMessageID: validID, MessageID: validID})
	if !errors.Is(err, ErrDirectMessageUnavailable) {
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
