package updatedescription

import (
	"context"
	"errors"
	"unicode/utf8"
)

var (
	ErrInvalidInput     = errors.New("invalid channel description input")
	ErrRevisionConflict = errors.New("channel topology revision conflict")
)

type Input struct {
	ActorID          string
	ChannelID        string
	Description      string
	ExpectedRevision int64
}

type Result struct {
	ID          string
	Description string
	Revision    int64
}

type Store interface {
	Update(context.Context, Input) (Result, error)
}
type Service struct{ store Store }

func New(store Store) Service { return Service{store: store} }

func (service Service) Update(ctx context.Context, input Input) (Result, error) {
	if input.ActorID == "" || input.ChannelID == "" || input.ExpectedRevision < 1 || utf8.RuneCountInString(input.Description) > 200 {
		return Result{}, ErrInvalidInput
	}
	return service.store.Update(ctx, input)
}
