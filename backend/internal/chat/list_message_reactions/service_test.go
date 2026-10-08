package listmessagereactions

import (
	"context"
	"errors"
	"testing"
)

type testStore struct{ calls int }

func (s *testStore) List(_ context.Context, _ Input) ([]Reaction, error) {
	s.calls++
	return []Reaction{}, nil
}
func TestReactionReadIsBoundedAndRejectsUnknownIDs(t *testing.T) {
	store := &testStore{}
	s := New(store)
	in := Input{ActorID: "11111111-1111-4111-8111-111111111111", ConversationID: "22222222-2222-4222-8222-222222222222", MessageIDs: []string{"33333333-3333-4333-8333-333333333333"}}
	if _, err := s.List(t.Context(), in); err != nil {
		t.Fatal(err)
	}
	in.MessageIDs = []string{"invalid"}
	if _, err := s.List(t.Context(), in); !errors.Is(err, ErrInvalidInput) {
		t.Fatal("invalid target accepted")
	}
	in.MessageIDs = make([]string, 101)
	if _, err := s.List(t.Context(), in); !errors.Is(err, ErrInvalidInput) {
		t.Fatal("unbounded request accepted")
	}
	if store.calls != 1 {
		t.Fatal("invalid read reached SQL")
	}
}
