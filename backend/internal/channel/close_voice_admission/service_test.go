package closevoiceadmission

import (
	"context"
	"errors"
	"testing"
)

func TestCloseRequiresActorChannelAndRevision(t *testing.T) {
	store := &fakeStore{result: Result{ID: "channel-1", Revision: 4, RevokedLeases: 2}}
	result, err := New(store).Close(context.Background(), Input{ActorID: "admin-1", ChannelID: "channel-1", ExpectedRevision: 3})
	if err != nil || store.input.ActorID != "admin-1" || result != store.result {
		t.Fatalf("error = %v, input = %#v, result = %#v", err, store.input, result)
	}
}

func TestCloseRejectsInvalidInputBeforePersistence(t *testing.T) {
	store := &fakeStore{}
	_, err := New(store).Close(context.Background(), Input{ActorID: "admin-1", ChannelID: "channel-1"})
	if !errors.Is(err, ErrInvalidInput) || store.called {
		t.Fatalf("error = %v, called = %v", err, store.called)
	}
}

type fakeStore struct {
	input  Input
	result Result
	called bool
}

func (store *fakeStore) Close(_ context.Context, input Input) (Result, error) {
	store.input, store.called = input, true
	return store.result, nil
}
