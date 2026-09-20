package releasevoicelease

import (
	"context"
	"crypto/sha256"
	"errors"
)

var ErrInvalidInput = errors.New("invalid voice lease release input")

type Input struct {
	ActorID, LeaseID string
	SessionDigest    [sha256.Size]byte
}
type Store interface {
	Release(context.Context, Input) error
}
type Service struct{ store Store }

func New(store Store) Service { return Service{store: store} }

func (service Service) Release(context context.Context, input Input) error {
	if input.ActorID == "" || input.LeaseID == "" || input.SessionDigest == [sha256.Size]byte{} {
		return ErrInvalidInput
	}
	return service.store.Release(context, input)
}
