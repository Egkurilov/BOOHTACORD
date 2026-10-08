package restorereadonlytext

import (
	"context"
	"errors"
	"github.com/google/uuid"
)

var ErrInvalidInput = errors.New("invalid readonly archive input")
var ErrConflict = errors.New("readonly archive revision or state conflict")

type Input struct {
	ActorID, ChannelID string
	ExpectedRevision   int64
}
type Result struct {
	ID       string `json:"id"`
	Revision int64  `json:"revision"`
}
type Store interface {
	Restore(context.Context, Input) (Result, error)
}
type Service struct{ store Store }

func New(store Store) Service { return Service{store} }
func (s Service) Restore(ctx context.Context, in Input) (Result, error) {
	if _, err := uuid.Parse(in.ActorID); err != nil {
		return Result{}, ErrInvalidInput
	}
	if _, err := uuid.Parse(in.ChannelID); err != nil {
		return Result{}, ErrInvalidInput
	}
	if in.ExpectedRevision < 1 {
		return Result{}, ErrInvalidInput
	}
	return s.store.Restore(ctx, in)
}
