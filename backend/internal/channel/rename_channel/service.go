package renamechannel

import (
	"context"
	"errors"

	"voice-platform/backend/internal/channel/category_name"
)

var (
	ErrInvalidInput     = errors.New("invalid channel rename input")
	ErrRevisionConflict = errors.New("channel topology revision conflict")
)

type Input struct {
	ActorID          string
	ChannelID        string
	Name             string
	ExpectedRevision int64
}

type Result struct {
	ID       string
	Name     string
	Revision int64
}

type Store interface {
	Rename(context.Context, Input) (Result, error)
}

type Service struct{ store Store }

func New(store Store) Service { return Service{store: store} }

func (service Service) Rename(ctx context.Context, input Input) (Result, error) {
	if input.ActorID == "" || input.ChannelID == "" || input.ExpectedRevision < 1 || categoryname.Validate(input.Name) != nil {
		return Result{}, ErrInvalidInput
	}
	return service.store.Rename(ctx, input)
}
