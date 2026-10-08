package changetextpin

import (
	"context"
	"errors"
	"github.com/google/uuid"
)

var ErrInvalidInput = errors.New("invalid pin input")
var ErrUnavailable = errors.New("pin target unavailable")

type Input struct {
	ActorID, ChannelID, MessageID string
	Present                       bool
}
type Result struct{ Changed bool }
type Store interface {
	Set(context.Context, Input) (Result, error)
}
type Service struct{ store Store }

func New(s Store) Service { return Service{s} }
func (s Service) Set(ctx context.Context, in Input) (Result, error) {
	for _, id := range []string{in.ActorID, in.ChannelID, in.MessageID} {
		if _, err := uuid.Parse(id); err != nil {
			return Result{}, ErrInvalidInput
		}
	}
	return s.store.Set(ctx, in)
}
