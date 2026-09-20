package releasevoicelease

import (
	"context"
	"crypto/sha256"
	"errors"
	"testing"
)

func TestReleasePassesOwningSession(t *testing.T) {
	digest := sha256.Sum256([]byte("session"))
	store := &fakeStore{}
	err := New(store).Release(context.Background(), Input{ActorID: "user-1", LeaseID: "lease-1", SessionDigest: digest})
	if err != nil || store.input.SessionDigest != digest || store.input.LeaseID != "lease-1" {
		t.Fatalf("error = %v, input = %#v", err, store.input)
	}
}

func TestReleaseRejectsEmptySessionBeforePersistence(t *testing.T) {
	store := &fakeStore{}
	err := New(store).Release(context.Background(), Input{ActorID: "user-1", LeaseID: "lease-1"})
	if !errors.Is(err, ErrInvalidInput) || store.called {
		t.Fatalf("error = %v, called = %v", err, store.called)
	}
}

type fakeStore struct {
	input  Input
	called bool
}

func (store *fakeStore) Release(_ context.Context, input Input) error {
	store.input, store.called = input, true
	return nil
}
