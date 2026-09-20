package logoutuser

import (
	"bytes"
	"context"
	"crypto/sha256"
	"testing"

	"voice-platform/backend/internal/identity/session"
)

func TestLogoutRevokesCurrentSessionDigest(t *testing.T) {
	issued, err := session.Issue()
	if err != nil {
		t.Fatalf("Issue() error = %v", err)
	}
	store := &fakeStore{}
	service := New(store)

	if err := service.Logout(context.Background(), issued.Token); err != nil {
		t.Fatalf("Logout() error = %v", err)
	}
	if !bytes.Equal(store.digest[:], issued.Digest[:]) {
		t.Fatal("Logout() did not revoke the session digest")
	}
}

func TestLogoutIgnoresMalformedCookie(t *testing.T) {
	store := &fakeStore{}
	if err := New(store).Logout(context.Background(), "malformed!"); err != nil {
		t.Fatalf("Logout() error = %v", err)
	}
	if store.called {
		t.Fatal("Logout() attempted to revoke a malformed token")
	}
}

type fakeStore struct {
	digest [sha256.Size]byte
	called bool
}

func (store *fakeStore) Revoke(_ context.Context, digest [sha256.Size]byte) error {
	store.called = true
	store.digest = digest
	return nil
}
