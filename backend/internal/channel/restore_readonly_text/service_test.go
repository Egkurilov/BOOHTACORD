package restorereadonlytext

import (
	"context"
	"errors"
	"testing"
)

type fakeStore struct{ calls int }

func (s *fakeStore) Restore(_ context.Context, in Input) (Result, error) {
	s.calls++
	return Result{ID: in.ChannelID, Revision: in.ExpectedRevision + 1}, nil
}
func TestRestoreValidatesIdentityAndRevision(t *testing.T) {
	s := &fakeStore{}
	service := New(s)
	in := Input{ActorID: "11111111-1111-4111-8111-111111111111", ChannelID: "22222222-2222-4222-8222-222222222222", ExpectedRevision: 0}
	if _, err := service.Restore(t.Context(), in); !errors.Is(err, ErrInvalidInput) || s.calls != 0 {
		t.Fatal(err)
	}
	in.ExpectedRevision = 2
	if result, err := service.Restore(t.Context(), in); err != nil || result.ID != in.ChannelID || s.calls != 1 {
		t.Fatal(err)
	}
}
