package acquirevoicelease

import (
	"context"
	"crypto/sha256"
	"errors"
	"testing"
)

func TestAcquirePassesExplicitTransferToStore(t *testing.T) {
	digest := sha256.Sum256([]byte("session"))
	store := &fakeStore{result: Result{ID: "lease-1", ChannelID: "voice-1", Transferred: true}}
	result, err := New(store).Acquire(context.Background(), Input{ActorID: "user-1", ChannelID: "voice-1", SessionDigest: digest, Transfer: true})
	if err != nil || !store.request.Transfer || store.request.SessionDigest != digest || result != store.result {
		t.Fatalf("error = %v, request = %#v, result = %#v", err, store.request, result)
	}
}

func TestAcquireReturnsExistingChannelWithoutImplicitTransfer(t *testing.T) {
	digest := sha256.Sum256([]byte("session"))
	store := &fakeStore{result: Result{ExistingChannelID: "voice-old"}, err: ErrActiveLease}
	result, err := New(store).Acquire(context.Background(), Input{ActorID: "user-1", ChannelID: "voice-new", SessionDigest: digest})
	if !errors.Is(err, ErrActiveLease) || result.ExistingChannelID != "voice-old" || store.request.Transfer {
		t.Fatalf("error = %v, result = %#v, request = %#v", err, result, store.request)
	}
}

func TestAcquireRejectsMissingSessionDigestBeforePersistence(t *testing.T) {
	store := &fakeStore{}
	_, err := New(store).Acquire(context.Background(), Input{ActorID: "user-1", ChannelID: "voice-1"})
	if !errors.Is(err, ErrInvalidInput) || store.called {
		t.Fatalf("error = %v, called = %v", err, store.called)
	}
}

type fakeStore struct {
	request Request
	result  Result
	err     error
	called  bool
}

func (store *fakeStore) Acquire(_ context.Context, request Request) (Result, error) {
	store.request, store.called = request, true
	return store.result, store.err
}
