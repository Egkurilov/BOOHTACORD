package updateownprofile

import (
	"context"
	"errors"
	"strings"
	"testing"
)

func TestUpdatePassesOnlyTheAuthenticatedAccountAndDisplayName(t *testing.T) {
	store := &fakeStore{profile: Profile{AccountID: "account-1", Login: "fixed-login", DisplayName: "Новое имя", Role: "MEMBER"}}
	profile, err := New(store).Update(context.Background(), Input{AccountID: "account-1", DisplayName: "Новое имя"})
	if err != nil || profile != store.profile || store.input != (Input{AccountID: "account-1", DisplayName: "Новое имя"}) {
		t.Fatalf("Update() = %#v, %v; input = %#v", profile, err, store.input)
	}
}

func TestUpdateValidatesUnicodeDisplayNameBeforePersistence(t *testing.T) {
	for _, displayName := range []string{"", strings.Repeat("я", 65)} {
		store := &fakeStore{}
		_, err := New(store).Update(context.Background(), Input{AccountID: "account-1", DisplayName: displayName})
		if !errors.Is(err, ErrInvalidDisplayName) || store.called {
			t.Fatalf("Update(%d runes) error = %v, persisted = %v", len([]rune(displayName)), err, store.called)
		}
	}
}

func TestUpdateAcceptsOneAndSixtyFourUnicodeCharacters(t *testing.T) {
	for _, displayName := range []string{"я", strings.Repeat("я", 64)} {
		store := &fakeStore{}
		if _, err := New(store).Update(context.Background(), Input{AccountID: "account-1", DisplayName: displayName}); err != nil || !store.called {
			t.Fatalf("Update(%d runes) error = %v, persisted = %v", len([]rune(displayName)), err, store.called)
		}
	}
}

func TestUpdateRejectsMissingAccountID(t *testing.T) {
	store := &fakeStore{}
	if _, err := New(store).Update(context.Background(), Input{DisplayName: "Имя"}); !errors.Is(err, ErrInvalidAccount) || store.called {
		t.Fatalf("Update() error = %v, persisted = %v", err, store.called)
	}
}

type fakeStore struct {
	input   Input
	profile Profile
	called  bool
}

func (store *fakeStore) Update(_ context.Context, input Input) (Profile, error) {
	store.input = input
	store.called = true
	return store.profile, nil
}
