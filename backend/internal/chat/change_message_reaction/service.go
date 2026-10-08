package changemessagereaction

import (
	"context"
	"errors"
	"github.com/google/uuid"
)

var ErrInvalidInput = errors.New("invalid reaction input")
var ErrUnavailable = errors.New("reaction target unavailable")

type Input struct {
	ActorID, ConversationID, MessageID, Emoji string
	Direct, Present                           bool
}
type Result struct {
	Changed    bool
	Recipients []string
}
type Store interface {
	Set(context.Context, Input) (Result, error)
}
type Service struct{ store Store }

func New(s Store) Service { return Service{s} }
func ValidEmoji(value string) bool {
	switch value {
	case "👍", "❤️", "😂", "🎉", "👀", "✅":
		return true
	}
	return false
}
func (s Service) Set(ctx context.Context, in Input) (Result, error) {
	for _, id := range []string{in.ActorID, in.ConversationID, in.MessageID} {
		if _, err := uuid.Parse(id); err != nil {
			return Result{}, ErrInvalidInput
		}
	}
	if !ValidEmoji(in.Emoji) {
		return Result{}, ErrInvalidInput
	}
	return s.store.Set(ctx, in)
}
