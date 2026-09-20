package deletedirectmessage

import (
	"context"
	"errors"
	"testing"
)

const validID = "11111111-1111-4111-8111-111111111111"

func TestDeletePersistsAuthorOwnedDirectMessage(t *testing.T) {
	store := &fakeStore{result: Result{ID: validID, Revision: 2}}
	result, err := New(store).Delete(context.Background(), Input{ActorID: validID, DirectMessageID: validID, MessageID: validID})
	if err != nil || result.Revision != 2 || store.request.ActorID != validID {
		t.Fatalf("result=%#v request=%#v error=%v", result, store.request, err)
	}
}

func TestDeleteRejectsInvalidInputBeforePersistence(t *testing.T) {
	store := &fakeStore{}
	_, err := New(store).Delete(context.Background(), Input{ActorID: "not-a-uuid", DirectMessageID: validID, MessageID: validID})
	if !errors.Is(err, ErrInvalidInput) || store.called {
		t.Fatalf("error=%v called=%v", err, store.called)
	}
}

func TestDeletePreservesDeniedResult(t *testing.T) {
	_, err := New(&fakeStore{err: ErrDeleteDenied}).Delete(context.Background(), Input{ActorID: validID, DirectMessageID: validID, MessageID: validID})
	if !errors.Is(err, ErrDeleteDenied) {
		t.Fatalf("error=%v", err)
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
