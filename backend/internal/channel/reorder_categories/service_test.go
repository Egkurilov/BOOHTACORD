package reordercategories

import (
	"context"
	"errors"
	"testing"
)

func TestReorderPassesFullOrderAndExpectedRevision(t *testing.T) {
	store := &fakeStore{result: Result{Revision: 3}}
	result, err := New(store).Reorder(context.Background(), Input{ActorID: "admin-1", ExpectedRevision: 2, IDs: []string{"category-2", "category-1"}})
	if err != nil {
		t.Fatalf("Reorder() error = %v", err)
	}
	if store.input.ActorID != "admin-1" || store.input.ExpectedRevision != 2 || len(store.input.IDs) != 2 || result.Revision != 3 {
		t.Fatalf("input = %#v, result = %#v", store.input, result)
	}
}

func TestReorderRejectsDuplicateOrBlankIdentifiers(t *testing.T) {
	for _, input := range []Input{
		{ActorID: "admin-1", ExpectedRevision: 1, IDs: []string{"category-1", "category-1"}},
		{ActorID: "admin-1", ExpectedRevision: 1, IDs: []string{""}},
		{ActorID: "admin-1", ExpectedRevision: 0, IDs: []string{"category-1"}},
	} {
		store := &fakeStore{}
		_, err := New(store).Reorder(context.Background(), input)
		if !errors.Is(err, ErrInvalidInput) || store.called {
			t.Fatalf("Reorder(%#v) error = %v, called = %v", input, err, store.called)
		}
	}
}

func TestReorderPreservesRevisionConflict(t *testing.T) {
	store := &fakeStore{err: ErrRevisionConflict}
	_, err := New(store).Reorder(context.Background(), Input{ActorID: "admin-1", ExpectedRevision: 2, IDs: []string{"category-1"}})
	if !errors.Is(err, ErrRevisionConflict) {
		t.Fatalf("Reorder() error = %v", err)
	}
}

type fakeStore struct {
	input  Input
	result Result
	err    error
	called bool
}

func (store *fakeStore) Reorder(_ context.Context, input Input) (Result, error) {
	store.input = input
	store.called = true
	return store.result, store.err
}
