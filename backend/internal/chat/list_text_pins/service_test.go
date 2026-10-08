package listtextpins

import (
	"context"
	"errors"
	"testing"
	"time"
)

type testStore struct{}

func (testStore) List(_ context.Context, in Request) ([]Pin, error) {
	return []Pin{{MessageID: "33333333-3333-4333-8333-333333333333", PinnedAt: time.Unix(10, 0).UTC()}, {MessageID: "44444444-4444-4444-8444-444444444444", PinnedAt: time.Unix(9, 0).UTC()}}, nil
}
func TestPinCursorRoundTripAndBounds(t *testing.T) {
	s := New(testStore{})
	in := Input{ActorID: "11111111-1111-4111-8111-111111111111", ChannelID: "22222222-2222-4222-8222-222222222222", Limit: 1}
	page, err := s.List(t.Context(), in)
	if err != nil || len(page.Pins) != 1 || page.NextCursor == "" {
		t.Fatal("bounded page lost")
	}
	in.Before = page.NextCursor
	if _, err := s.List(t.Context(), in); err != nil {
		t.Fatal("cursor rejected")
	}
	in.Before = "invalid"
	if _, err := s.List(t.Context(), in); !errors.Is(err, ErrInvalidInput) {
		t.Fatal("invalid cursor accepted")
	}
	in.Before = ""
	in.Limit = 51
	if _, err := s.List(t.Context(), in); !errors.Is(err, ErrInvalidInput) {
		t.Fatal("unbounded request accepted")
	}
}
