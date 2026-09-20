package listdirectmessagecandidates

import (
	"context"
	"errors"
	"testing"
)

const (
	candidateActor = "11111111-1111-4111-8111-111111111111"
	candidateA     = "22222222-2222-4222-8222-222222222222"
	candidateB     = "33333333-3333-4333-8333-333333333333"
	candidateC     = "44444444-4444-4444-8444-444444444444"
)

func TestListReturnsOneExtraRowAsCursorWithoutLeakingRoleOrBlockState(t *testing.T) {
	store := &fakeStore{candidates: []Candidate{{ID: candidateA, DisplayName: "Аня"}, {ID: candidateB, DisplayName: "Борис"}, {ID: candidateC, DisplayName: "Вика"}}}

	result, err := New(store).List(context.Background(), Input{ActorID: candidateActor, Limit: 2})

	if err != nil || len(result.Candidates) != 2 || result.NextAfter != candidateB || store.request != (Request{Input: Input{ActorID: candidateActor, Limit: 2}}) {
		t.Fatalf("result=%#v request=%#v error=%v", result, store.request, err)
	}
}

func TestListRejectsInvalidCursorBeforePersistence(t *testing.T) {
	store := &fakeStore{}

	_, err := New(store).List(context.Background(), Input{ActorID: candidateActor, After: "not-a-uuid", Limit: 50})

	if !errors.Is(err, ErrInvalidInput) || store.called {
		t.Fatalf("error=%v called=%v", err, store.called)
	}
}

type fakeStore struct {
	called     bool
	request    Request
	candidates []Candidate
}

func (store *fakeStore) List(_ context.Context, request Request) ([]Candidate, error) {
	store.called, store.request = true, request
	return store.candidates, nil
}
