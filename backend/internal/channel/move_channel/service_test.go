package movechannel

import (
	"context"
	"errors"
	"testing"
)

func TestMovePassesTargetCategoryAndRevision(t *testing.T) {
	store := &fakeStore{result: Result{ID: "channel-1", CategoryID: "category-2", Position: 1, Revision: 3}}
	result, err := New(store).Move(context.Background(), Input{ActorID: "admin-1", ChannelID: "channel-1", CategoryID: "category-2", ExpectedRevision: 2})
	if err != nil {
		t.Fatalf("Move() error = %v", err)
	}
	if store.input.ActorID != "admin-1" || store.input.ChannelID != "channel-1" || store.input.CategoryID != "category-2" || result != store.result {
		t.Fatalf("input = %#v, result = %#v", store.input, result)
	}
}

func TestMoveRejectsIncompleteInputBeforePersistence(t *testing.T) {
	store := &fakeStore{}
	_, err := New(store).Move(context.Background(), Input{ActorID: "admin-1", ChannelID: "channel-1", ExpectedRevision: 1})
	if !errors.Is(err, ErrInvalidInput) || store.called {
		t.Fatalf("Move() error = %v, called = %v", err, store.called)
	}
}

type fakeStore struct {
	input  Input
	result Result
	called bool
}

func (store *fakeStore) Move(_ context.Context, input Input) (Result, error) {
	store.input, store.called = input, true
	return store.result, nil
}
