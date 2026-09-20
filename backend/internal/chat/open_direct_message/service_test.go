package opendirectmessage

import (
	"context"
	"errors"
	"testing"
	"time"
)

const actorID = "11111111-1111-4111-8111-111111111111"
const participantID = "22222222-2222-4222-8222-222222222222"

func TestOpenCreatesOrReturnsCanonicalPair(t *testing.T) {
	store := &fakeStore{result: Result{ID: "33333333-3333-4333-8333-333333333333", ParticipantOneID: actorID, ParticipantTwoID: participantID, CreatedAt: time.Unix(1, 0)}}
	service := New(store)
	service.newID = func() (string, error) { return "33333333-3333-4333-8333-333333333333", nil }

	result, err := service.Open(context.Background(), Input{ActorID: actorID, ParticipantID: participantID})

	if err != nil || store.request != (Request{ID: "33333333-3333-4333-8333-333333333333", Input: Input{ActorID: actorID, ParticipantID: participantID}}) || result != store.result {
		t.Fatalf("request=%#v result=%#v error=%v", store.request, result, err)
	}
}

func TestOpenRejectsSelfPairBeforePersistence(t *testing.T) {
	store := &fakeStore{}
	_, err := New(store).Open(context.Background(), Input{ActorID: actorID, ParticipantID: actorID})
	if !errors.Is(err, ErrInvalidInput) || store.called {
		t.Fatalf("error=%v called=%v", err, store.called)
	}
}

type fakeStore struct {
	called  bool
	request Request
	result  Result
}

func (store *fakeStore) Open(_ context.Context, request Request) (Result, error) {
	store.called = true
	store.request = request
	return store.result, nil
}
