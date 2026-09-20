package closevoiceadmission

import (
	"context"
	"errors"
)

var (
	ErrInvalidInput     = errors.New("invalid voice admission close input")
	ErrRevisionConflict = errors.New("channel topology revision conflict")
)

type Input struct {
	ActorID, ChannelID string
	ExpectedRevision   int64
}
type Result struct {
	ID            string
	Revision      int64
	RevokedLeases int64
}
type Store interface {
	Close(context.Context, Input) (Result, error)
}
type Service struct{ store Store }

func New(store Store) Service { return Service{store: store} }

func (service Service) Close(context context.Context, input Input) (Result, error) {
	if input.ActorID == "" || input.ChannelID == "" || input.ExpectedRevision < 1 {
		return Result{}, ErrInvalidInput
	}
	result, err := service.store.Close(context, input)
	if errors.Is(err, ErrRevisionConflict) {
		return Result{}, ErrRevisionConflict
	}
	if err != nil {
		return Result{}, err
	}
	return result, nil
}
