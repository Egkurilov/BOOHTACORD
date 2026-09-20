package renamecategory

import (
	"context"
	"errors"
	"testing"
)

func TestRenamePassesNameAndExpectedRevision(t *testing.T) {
	store := &fakeStore{result: Result{ID: "category-1", Name: "Игры", Revision: 3}}
	result, err := New(store).Rename(context.Background(), Input{ActorID: "admin-1", CategoryID: "category-1", Name: "Игры", ExpectedRevision: 2})
	if err != nil {
		t.Fatalf("Rename() error = %v", err)
	}
	if store.input.ActorID != "admin-1" || store.input.CategoryID != "category-1" || store.input.Name != "Игры" || result != store.result {
		t.Fatalf("input = %#v, result = %#v", store.input, result)
	}
}

func TestRenameRejectsInvalidNameOrRevision(t *testing.T) {
	for _, input := range []Input{
		{ActorID: "admin-1", CategoryID: "category-1", Name: "", ExpectedRevision: 1},
		{ActorID: "admin-1", CategoryID: "category-1", Name: "Игры", ExpectedRevision: 0},
	} {
		store := &fakeStore{}
		_, err := New(store).Rename(context.Background(), input)
		if !errors.Is(err, ErrInvalidInput) || store.called {
			t.Fatalf("Rename(%#v) error = %v, called = %v", input, err, store.called)
		}
	}
}

type fakeStore struct {
	input  Input
	result Result
	called bool
}

func (store *fakeStore) Rename(_ context.Context, input Input) (Result, error) {
	store.input = input
	store.called = true
	return store.result, nil
}
