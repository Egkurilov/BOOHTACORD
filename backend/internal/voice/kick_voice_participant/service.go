package kickvoiceparticipant

import (
	"context"
	"errors"
)

var ErrInvalidInput = errors.New("invalid voice kick input")

type Input struct{ ActorID, TargetID string }
type Result struct{ RevokedLeases int64 }
type Store interface {
	Kick(context.Context, Input) (Result, error)
}
type Service struct{ store Store }

func New(store Store) Service { return Service{store: store} }
func (service Service) Kick(context context.Context, input Input) (Result, error) {
	if input.ActorID == "" || input.TargetID == "" {
		return Result{}, ErrInvalidInput
	}
	return service.store.Kick(context, input)
}
