package listarchivedtext

import (
	"context"
	"errors"
	"testing"
)

type fakeStore struct{ calls int }

func (s *fakeStore) List(context.Context, Input) (Result, error) {
	s.calls++
	return Result{Revision: 2, Channels: []Channel{{ID: "first"}, {ID: "next"}}}, nil
}
func TestListValidatesAndProducesCursor(t *testing.T) {
	s := &fakeStore{}
	service := New(s)
	if _, err := service.List(t.Context(), Input{ActorID: "bad", Limit: 1}); !errors.Is(err, ErrInvalidInput) || s.calls != 0 {
		t.Fatal(err)
	}
	page, err := service.List(t.Context(), Input{ActorID: "11111111-1111-4111-8111-111111111111", Limit: 1})
	if err != nil || len(page.Channels) != 1 || page.NextCursor != "first" {
		t.Fatalf("page=%+v err=%v", page, err)
	}
}
