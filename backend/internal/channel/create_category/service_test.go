package createcategory

import (
	"context"
	"errors"
	"testing"
)

func TestCreateValidatesNameAndPersistsNewCategory(t *testing.T) {
	store := &fakeStore{result: Result{ID: "category-1", Name: "Общее", Position: 0, Revision: 1}}
	service := New(store)
	service.newID = func() (string, error) { return "category-1", nil }

	result, err := service.Create(context.Background(), Input{ActorID: "admin-1", Name: "Общее"})
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	if store.request.ID != "category-1" || store.request.ActorID != "admin-1" || store.request.Name != "Общее" || result != store.result {
		t.Fatalf("request = %#v, result = %#v", store.request, result)
	}
}

func TestCreateRejectsInvalidNameBeforePersistence(t *testing.T) {
	store := &fakeStore{}
	_, err := New(store).Create(context.Background(), Input{ActorID: "admin-1", Name: ""})
	if !errors.Is(err, ErrInvalidInput) || store.called {
		t.Fatalf("Create() error = %v, called = %v", err, store.called)
	}
}

type fakeStore struct {
	request Request
	result  Result
	called  bool
}

func (store *fakeStore) Create(_ context.Context, request Request) (Result, error) {
	store.request = request
	store.called = true
	return store.result, nil
}
