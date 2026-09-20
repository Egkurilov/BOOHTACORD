package createchannel

import (
	"context"
	"errors"
	"testing"
)

func TestCreatePersistsFixedChannelKindWithinCategory(t *testing.T) {
	store := &fakeStore{result: Result{ID: "channel-1", CategoryID: "category-1", Name: "Голос", Kind: KindVoice, Position: 0, Revision: 2}}
	service := New(store)
	service.newID = func() (string, error) { return "channel-1", nil }

	result, err := service.Create(context.Background(), Input{ActorID: "admin-1", CategoryID: "category-1", Name: "Голос", Kind: KindVoice})
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	if store.request.ID != "channel-1" || store.request.CategoryID != "category-1" || store.request.Kind != KindVoice || result != store.result {
		t.Fatalf("request = %#v, result = %#v", store.request, result)
	}
}

func TestCreateRejectsUnknownKindAndInvalidNameBeforePersistence(t *testing.T) {
	for _, input := range []Input{
		{ActorID: "admin-1", CategoryID: "category-1", Name: "", Kind: KindText},
		{ActorID: "admin-1", CategoryID: "category-1", Name: "Общее", Kind: "VIDEO"},
	} {
		store := &fakeStore{}
		_, err := New(store).Create(context.Background(), input)
		if !errors.Is(err, ErrInvalidInput) || store.called {
			t.Fatalf("Create(%#v) error = %v, called = %v", input, err, store.called)
		}
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
