package rolepolicy

import (
	"context"
	"errors"
	"testing"

	permissionregistry "voice-platform/backend/internal/authorization/permission_registry"
)

func TestUpdateMemberValidatesAndForwardsCommand(t *testing.T) {
	store := &fakeStore{result: permissionregistry.Policy{TextCreate: true, Revision: 4}}
	command := UpdateCommand{ActorID: "admin-1", ExpectedRevision: 3, Policy: permissionregistry.Policy{TextCreate: true}, ConfirmDeleteGrants: true}
	result, err := New(store).UpdateMember(context.Background(), command)
	if err != nil || result.Revision != 4 || store.command != command {
		t.Fatalf("UpdateMember() = %#v, %v; command = %#v", result, err, store.command)
	}
	for _, invalid := range []UpdateCommand{{ExpectedRevision: 1}, {ActorID: "admin", ExpectedRevision: 0}} {
		if _, err := New(store).UpdateMember(context.Background(), invalid); !errors.Is(err, ErrInvalidInput) {
			t.Fatalf("invalid error = %v", err)
		}
	}
}

type fakeStore struct {
	command UpdateCommand
	result  permissionregistry.Policy
}

func (store *fakeStore) UpdateMember(_ context.Context, command UpdateCommand) (permissionregistry.Policy, error) {
	store.command = command
	return store.result, nil
}
