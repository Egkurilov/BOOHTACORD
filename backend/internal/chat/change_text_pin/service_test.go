package changetextpin

import (
	"context"
	"errors"
	"testing"
)

type testStore struct{ last Input }

func (s *testStore) Set(_ context.Context, in Input) (Result, error) {
	s.last = in
	return Result{}, nil
}
func TestPinValidatesIDsAndPreservesExplicitDesiredState(t *testing.T) {
	s := &testStore{}
	service := New(s)
	in := Input{ActorID: "11111111-1111-4111-8111-111111111111", ChannelID: "22222222-2222-4222-8222-222222222222", MessageID: "33333333-3333-4333-8333-333333333333", Present: true}
	if _, err := service.Set(t.Context(), in); err != nil || !s.last.Present {
		t.Fatal("pin state lost")
	}
	in.Present = false
	if _, err := service.Set(t.Context(), in); err != nil || s.last.Present {
		t.Fatal("unpin state lost")
	}
	in.ChannelID = "invalid"
	if _, err := service.Set(t.Context(), in); !errors.Is(err, ErrInvalidInput) {
		t.Fatal("invalid target accepted")
	}
}
