package archivetextchannel

import (
	"context"
	"errors"
	"testing"
)

func TestArchiveRequiresExplicitConfirmationAndRevision(t *testing.T) {
	store := &fakeStore{result: Result{ID: "channel-1", Revision: 4}}
	result, err := New(store).Archive(context.Background(), Input{ActorID: "admin-1", ChannelID: "channel-1", ExpectedRevision: 3, ConfirmArchive: true})
	if err != nil {
		t.Fatalf("Archive() error = %v", err)
	}
	if store.input.ActorID != "admin-1" || !store.input.ConfirmArchive || result != store.result {
		t.Fatalf("input = %#v, result = %#v", store.input, result)
	}
}

func TestArchiveRejectsMissingConfirmationBeforePersistence(t *testing.T) {
	store := &fakeStore{}
	_, err := New(store).Archive(context.Background(), Input{ActorID: "admin-1", ChannelID: "channel-1", ExpectedRevision: 3})
	if !errors.Is(err, ErrInvalidInput) || store.called {
		t.Fatalf("Archive() error = %v, called = %v", err, store.called)
	}
}

type fakeStore struct {
	input  Input
	result Result
	called bool
}

func (store *fakeStore) Archive(_ context.Context, input Input) (Result, error) {
	store.input, store.called = input, true
	return store.result, nil
}
