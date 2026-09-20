package deleteemptycategory

import (
	"context"
	"errors"
)

var (
	ErrInvalidInput     = errors.New("invalid empty category deletion input")
	ErrRevisionConflict = errors.New("category deletion conflict")
)

type Input struct {
	ActorID, CategoryID string
	ExpectedRevision    int64
}
type Result struct {
	ID       string
	Revision int64
}
type Store interface {
	Delete(context.Context, Input) (Result, error)
}
type Service struct{ store Store }

func New(store Store) Service { return Service{store: store} }
func (service Service) Delete(ctx context.Context, input Input) (Result, error) {
	if input.ActorID == "" || input.CategoryID == "" || input.ExpectedRevision < 1 {
		return Result{}, ErrInvalidInput
	}
	return service.store.Delete(ctx, input)
}
