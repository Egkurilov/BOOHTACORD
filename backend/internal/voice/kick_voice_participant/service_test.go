package kickvoiceparticipant

import (
	"context"
	"errors"
	"testing"
)

func TestKickPassesAdministratorAndTarget(t *testing.T) {
	store := &fakeStore{result: Result{RevokedLeases: 1}}
	result, err := New(store).Kick(context.Background(), Input{ActorID: "admin-1", TargetID: "user-1"})
	if err != nil || store.input.TargetID != "user-1" || result.RevokedLeases != 1 {
		t.Fatalf("error = %v, input = %#v, result = %#v", err, store.input, result)
	}
}
func TestKickRejectsMissingTargetBeforePersistence(t *testing.T) {
	store := &fakeStore{}
	_, err := New(store).Kick(context.Background(), Input{ActorID: "admin-1"})
	if !errors.Is(err, ErrInvalidInput) || store.called {
		t.Fatalf("error = %v, called = %v", err, store.called)
	}
}

type fakeStore struct {
	input  Input
	result Result
	called bool
}

func (store *fakeStore) Kick(_ context.Context, input Input) (Result, error) {
	store.input, store.called = input, true
	return store.result, nil
}
