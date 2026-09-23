package readownprofile

import (
	"context"
	"testing"
)

func TestReadReturnsOnlyTheRequestedAccountProfile(t *testing.T) {
	store := &fakeStore{profile: Profile{AccountID: "account-1", Login: "fixed-login", DisplayName: "Новое имя", Role: "MEMBER"}}
	profile, err := New(store).Read(context.Background(), "account-1")
	if err != nil || profile != store.profile || store.accountID != "account-1" {
		t.Fatalf("Read() = %#v, %v; lookup ID = %q", profile, err, store.accountID)
	}
}

func TestReadRejectsMissingAccountIDBeforeStoreAccess(t *testing.T) {
	store := &fakeStore{}
	if _, err := New(store).Read(context.Background(), ""); err != ErrInvalidAccount || store.called {
		t.Fatalf("Read() error = %v, store called = %v", err, store.called)
	}
}

type fakeStore struct {
	profile   Profile
	accountID string
	called    bool
}

func (store *fakeStore) Find(_ context.Context, accountID string) (Profile, error) {
	store.accountID = accountID
	store.called = true
	return store.profile, nil
}
