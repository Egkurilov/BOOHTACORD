package changemessagereaction

import (
	"context"
	"errors"
	"testing"
)

type testStore struct {
	calls int
	last  Input
}

func (s *testStore) Set(_ context.Context, in Input) (Result, error) {
	s.calls++
	s.last = in
	return Result{}, nil
}
func TestOnlySixApprovedEmojiAndExplicitDesiredStateReachStore(t *testing.T) {
	s := &testStore{}
	service := New(s)
	in := Input{ActorID: "11111111-1111-4111-8111-111111111111", ConversationID: "22222222-2222-4222-8222-222222222222", MessageID: "33333333-3333-4333-8333-333333333333", Present: true}
	for _, emoji := range []string{"👍", "❤️", "😂", "🎉", "👀", "✅"} {
		in.Emoji = emoji
		if _, err := service.Set(t.Context(), in); err != nil {
			t.Fatal(err)
		}
	}
	if s.calls != 6 || !s.last.Present {
		t.Fatal("approved desired state lost")
	}
	for _, emoji := range []string{"", "😀", "❤", "👍 body"} {
		in.Emoji = emoji
		if _, err := service.Set(t.Context(), in); !errors.Is(err, ErrInvalidInput) {
			t.Fatal("unsupported reaction accepted")
		}
	}
	in.Emoji = "✅"
	in.Present = false
	if _, err := service.Set(t.Context(), in); err != nil || s.last.Present {
		t.Fatal("delete desired state lost")
	}
	in.MessageID = "invalid"
	if _, err := service.Set(t.Context(), in); !errors.Is(err, ErrInvalidInput) {
		t.Fatal("invalid target accepted")
	}
}
