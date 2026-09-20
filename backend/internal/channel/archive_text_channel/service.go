package archivetextchannel

import (
	"context"
	"errors"
)

var (
	ErrInvalidInput     = errors.New("invalid text channel archive input")
	ErrRevisionConflict = errors.New("channel topology revision conflict")
)

type Input struct {
	ActorID, ChannelID string
	ExpectedRevision   int64
	ConfirmArchive     bool
}
type Result struct {
	ID       string
	Revision int64
}
type Store interface {
	Archive(context.Context, Input) (Result, error)
}
type Service struct{ store Store }

func New(store Store) Service { return Service{store: store} }

func (service Service) Archive(context context.Context, input Input) (Result, error) {
	if input.ActorID == "" || input.ChannelID == "" || input.ExpectedRevision < 1 || !input.ConfirmArchive {
		return Result{}, ErrInvalidInput
	}
	result, err := service.store.Archive(context, input)
	if errors.Is(err, ErrRevisionConflict) {
		return Result{}, ErrRevisionConflict
	}
	if err != nil {
		return Result{}, err
	}
	return result, nil
}
