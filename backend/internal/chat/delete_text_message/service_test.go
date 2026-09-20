package deletetextmessage

import (
	"context"
	"errors"
	"testing"
)

const validID = "a1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"

func TestDeletePassesVerifiedRoleToStore(t *testing.T) {
	store := &fakeStore{result: Result{ID: validID, Revision: 2}}
	result, err := New(store).Delete(context.Background(), Input{ActorID: validID, ActorRole: "ADMINISTRATOR", ChannelID: validID, MessageID: validID})
	if err != nil || store.request.ActorRole != "ADMINISTRATOR" || result.Revision != 2 {
		t.Fatalf("request = %#v, result = %#v, error = %v", store.request, result, err)
	}
}

func TestDeleteRejectsInvalidRoleBeforePersistence(t *testing.T) {
	store := &fakeStore{}
	_, err := New(store).Delete(context.Background(), Input{ActorID: validID, ActorRole: "OWNER", ChannelID: validID, MessageID: validID})
	if !errors.Is(err, ErrInvalidInput) || store.called {
		t.Fatalf("error = %v, called = %v", err, store.called)
	}
}

func TestDeletePreservesDeniedResult(t *testing.T) {
	_, err := New(&fakeStore{err: ErrDeleteDenied}).Delete(context.Background(), Input{ActorID: validID, ActorRole: "MEMBER", ChannelID: validID, MessageID: validID})
	if !errors.Is(err, ErrDeleteDenied) {
		t.Fatalf("error = %v", err)
	}
}

type fakeStore struct {
	called  bool
	request Request
	result  Result
	err     error
}

func (store *fakeStore) Delete(_ context.Context, request Request) (Result, error) {
	store.called, store.request = true, request
	return store.result, store.err
}
