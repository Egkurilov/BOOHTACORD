package editdirectmessage

import (
	"context"
	"errors"
	"strings"
	"testing"
)

const validID = "11111111-1111-4111-8111-111111111111"

func TestEditPersistsExpectedRevision(t *testing.T) {
	store := &fakeStore{result: Result{ID: validID, Revision: 2}}
	result, err := New(store).Edit(context.Background(), Input{ActorID: validID, DirectMessageID: validID, MessageID: validID, Body: "исправлено", ExpectedRevision: 1})
	if err != nil || store.request.ExpectedRevision != 1 || result.Revision != 2 {
		t.Fatalf("request=%#v result=%#v error=%v", store.request, result, err)
	}
}

func TestEditRejectsUnsafeInputBeforePersistence(t *testing.T) {
	for _, input := range []Input{
		{ActorID: validID, DirectMessageID: validID, MessageID: validID, Body: "", ExpectedRevision: 1},
		{ActorID: validID, DirectMessageID: validID, MessageID: validID, Body: strings.Repeat("я", 8001), ExpectedRevision: 1},
		{ActorID: validID, DirectMessageID: validID, MessageID: validID, Body: "ok", ExpectedRevision: 0},
	} {
		store := &fakeStore{}
		_, err := New(store).Edit(context.Background(), input)
		if !errors.Is(err, ErrInvalidInput) || store.called {
			t.Fatalf("input=%#v error=%v called=%v", input, err, store.called)
		}
	}
}

func TestEditPreservesConflict(t *testing.T) {
	_, err := New(&fakeStore{err: ErrConflict}).Edit(context.Background(), Input{ActorID: validID, DirectMessageID: validID, MessageID: validID, Body: "ok", ExpectedRevision: 1})
	if !errors.Is(err, ErrConflict) {
		t.Fatalf("error=%v", err)
	}
}

type fakeStore struct {
	called  bool
	request Request
	result  Result
	err     error
}

func (store *fakeStore) Edit(_ context.Context, request Request) (Result, error) {
	store.called, store.request = true, request
	return store.result, store.err
}
