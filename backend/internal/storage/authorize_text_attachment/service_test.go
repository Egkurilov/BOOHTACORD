package authorizetextattachment

import (
	"context"
	"errors"
	"testing"
)

const (
	userID    = "a1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
	channelID = "b1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
)

func TestAuthorizeDelegatesValidCurrentTarget(t *testing.T) {
	store := &fakeStore{}
	err := New(store).Authorize(context.Background(), Input{ActorID: userID, ChannelID: channelID})
	if err != nil || !store.called || store.input.ActorID != userID || store.input.ChannelID != channelID {
		t.Fatalf("input = %#v, called = %v, error = %v", store.input, store.called, err)
	}
}

func TestAuthorizeRejectsMalformedTargetBeforeStore(t *testing.T) {
	store := &fakeStore{}
	err := New(store).Authorize(context.Background(), Input{ActorID: "invalid", ChannelID: channelID})
	if !errors.Is(err, ErrInvalidInput) || store.called {
		t.Fatalf("called = %v, error = %v", store.called, err)
	}
}

func TestAuthorizePreservesUnavailableTarget(t *testing.T) {
	err := New(&fakeStore{err: ErrTargetUnavailable}).Authorize(context.Background(), Input{ActorID: userID, ChannelID: channelID})
	if !errors.Is(err, ErrTargetUnavailable) {
		t.Fatalf("error = %v", err)
	}
}

type fakeStore struct {
	called bool
	input  Input
	err    error
}

func (store *fakeStore) Authorize(_ context.Context, input Input) error {
	store.called = true
	store.input = input
	return store.err
}
