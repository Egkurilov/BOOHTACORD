package adminaccount

import (
	"context"
	"errors"
	"testing"
)

func TestUpdatePassesActorTargetRoleAndBlockState(t *testing.T) {
	store := &fakeStore{account: Account{ID: "target", Role: RoleMember, Blocked: true}}
	service := New(store)
	account, err := service.Update(context.Background(), Input{ActorID: "actor", AccountID: "target", Role: RoleMember, Blocked: true})
	if err != nil {
		t.Fatalf("Update() error = %v", err)
	}
	if store.input.ActorID != "actor" || store.input.AccountID != "target" || account != store.account {
		t.Fatalf("input = %#v, account = %#v", store.input, account)
	}
}

func TestUpdateRejectsUnknownRoleBeforePersistence(t *testing.T) {
	store := &fakeStore{}
	_, err := New(store).Update(context.Background(), Input{ActorID: "actor", AccountID: "target", Role: "OWNER"})
	if !errors.Is(err, ErrInvalidInput) || store.called {
		t.Fatalf("Update() error = %v, called = %v", err, store.called)
	}
}

func TestUpdatePreservesLastAdministratorProtection(t *testing.T) {
	store := &fakeStore{err: ErrUpdateDenied}
	_, err := New(store).Update(context.Background(), Input{ActorID: "actor", AccountID: "target", Role: RoleMember, Blocked: true})
	if !errors.Is(err, ErrUpdateDenied) {
		t.Fatalf("Update() error = %v", err)
	}
}

type fakeStore struct {
	input   Input
	account Account
	err     error
	called  bool
}

func (store *fakeStore) Update(_ context.Context, input Input) (Account, error) {
	store.input = input
	store.called = true
	return store.account, store.err
}
