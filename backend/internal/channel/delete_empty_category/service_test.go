package deleteemptycategory

import (
	"context"
	"errors"
	"testing"
)

func TestDeleteValidatesAndForwardsRevision(t *testing.T) {
	store := &fakeStore{result: Result{ID: "category-1", Revision: 3}}
	result, err := New(store).Delete(context.Background(), Input{ActorID: "admin-1", CategoryID: "category-1", ExpectedRevision: 2})
	if err != nil || result != store.result || store.input.ExpectedRevision != 2 {
		t.Fatalf("result=%#v input=%#v err=%v", result, store.input, err)
	}
	_, err = New(store).Delete(context.Background(), Input{})
	if !errors.Is(err, ErrInvalidInput) {
		t.Fatal(err)
	}
}

type fakeStore struct {
	input  Input
	result Result
}

func (s *fakeStore) Delete(_ context.Context, input Input) (Result, error) {
	s.input = input
	return s.result, nil
}
