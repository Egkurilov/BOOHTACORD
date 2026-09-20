package authenticatesession

import (
	"context"
	"crypto/sha256"
	"errors"
	"testing"

	"voice-platform/backend/internal/identity/session"
)

func TestAuthenticateUsesActiveSessionDigest(t *testing.T) {
	issued, err := session.Issue()
	if err != nil {
		t.Fatalf("Issue() error = %v", err)
	}
	store := &fakeStore{principal: Principal{AccountID: "account-1", Role: "MEMBER"}}

	principal, err := New(store).Authenticate(context.Background(), issued.Token)
	if err != nil {
		t.Fatalf("Authenticate() error = %v", err)
	}
	if principal.AccountID != store.principal.AccountID || principal.Role != store.principal.Role || principal.SessionDigest != issued.Digest || store.digest != issued.Digest {
		t.Fatalf("principal = %#v, digest = %x", principal, store.digest)
	}
}

func TestAuthenticateRejectsMalformedAndRevokedTokens(t *testing.T) {
	store := &fakeStore{}
	if _, err := New(store).Authenticate(context.Background(), "malformed!"); !errors.Is(err, ErrUnauthenticated) || store.called {
		t.Fatalf("malformed token error = %v, called = %t", err, store.called)
	}

	issued, err := session.Issue()
	if err != nil {
		t.Fatalf("Issue() error = %v", err)
	}
	store = &fakeStore{err: ErrSessionNotFound}
	if _, err := New(store).Authenticate(context.Background(), issued.Token); !errors.Is(err, ErrUnauthenticated) {
		t.Fatalf("revoked token error = %v", err)
	}
}

type fakeStore struct {
	principal Principal
	digest    [sha256.Size]byte
	err       error
	called    bool
}

func (store *fakeStore) FindActive(_ context.Context, digest [sha256.Size]byte) (Principal, error) {
	store.called = true
	store.digest = digest
	return store.principal, store.err
}
