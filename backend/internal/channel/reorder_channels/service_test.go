package reorderchannels

import (
	"context"
	"errors"
	"testing"
)

func TestReorderPassesCategoryOrderAndRevision(t *testing.T) {
	store := &fakeStore{result: Result{Revision: 4}}
	result, err := New(store).Reorder(context.Background(), Input{ActorID: "admin-1", CategoryID: "category-1", ExpectedRevision: 3, IDs: []string{"channel-2", "channel-1"}})
	if err != nil {
		t.Fatalf("Reorder() error = %v", err)
	}
	if store.input.ActorID != "admin-1" || store.input.CategoryID != "category-1" || store.input.ExpectedRevision != 3 || len(store.input.IDs) != 2 || result.Revision != 4 {
		t.Fatalf("input = %#v, result = %#v", store.input, result)
	}
}

func TestReorderRejectsIncompleteIdentifiersBeforePersistence(t *testing.T) {
	for _, input := range []Input{
		{ActorID: "admin-1", CategoryID: "category-1", ExpectedRevision: 1, IDs: []string{"channel-1", "channel-1"}},
		{ActorID: "admin-1", CategoryID: "category-1", ExpectedRevision: 1, IDs: []string{""}},
		{ActorID: "admin-1", CategoryID: "", ExpectedRevision: 1, IDs: []string{"channel-1"}},
	} {
		store := &fakeStore{}
		_, err := New(store).Reorder(context.Background(), input)
		if !errors.Is(err, ErrInvalidInput) || store.called {
			t.Fatalf("Reorder(%#v) error = %v, called = %v", input, err, store.called)
		}
	}
}

type fakeStore struct {
	input  Input
	result Result
	called bool
}

func (store *fakeStore) Reorder(_ context.Context, input Input) (Result, error) {
	store.input, store.called = input, true
	return store.result, nil
}
