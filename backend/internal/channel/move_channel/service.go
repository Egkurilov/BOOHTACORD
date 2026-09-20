package movechannel

import (
	"context"
	"errors"
)

var (
	ErrInvalidInput     = errors.New("invalid channel move input")
	ErrRevisionConflict = errors.New("channel topology revision conflict")
)

type Input struct {
	ActorID          string
	ChannelID        string
	CategoryID       string
	ExpectedRevision int64
}

type Result struct {
	ID         string
	CategoryID string
	Position   int
	Revision   int64
}

type Store interface {
	Move(context.Context, Input) (Result, error)
}

type Service struct{ store Store }

func New(store Store) Service { return Service{store: store} }

func (service Service) Move(context context.Context, input Input) (Result, error) {
	if input.ActorID == "" || input.ChannelID == "" || input.CategoryID == "" || input.ExpectedRevision < 1 {
		return Result{}, ErrInvalidInput
	}
	result, err := service.store.Move(context, input)
	if errors.Is(err, ErrRevisionConflict) {
		return Result{}, ErrRevisionConflict
	}
	if err != nil {
		return Result{}, err
	}
	return result, nil
}
