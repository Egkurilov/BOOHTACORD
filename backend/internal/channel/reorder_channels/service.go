package reorderchannels

import (
	"context"
	"errors"
)

var (
	ErrInvalidInput     = errors.New("invalid channel reorder input")
	ErrRevisionConflict = errors.New("channel topology revision conflict")
)

type Input struct {
	ActorID, CategoryID string
	ExpectedRevision    int64
	IDs                 []string
}
type Result struct{ Revision int64 }
type Store interface {
	Reorder(context.Context, Input) (Result, error)
}
type Service struct{ store Store }

func New(store Store) Service { return Service{store: store} }

func (service Service) Reorder(context context.Context, input Input) (Result, error) {
	if input.ActorID == "" || input.CategoryID == "" || input.ExpectedRevision < 1 || !uniqueNonEmpty(input.IDs) {
		return Result{}, ErrInvalidInput
	}
	result, err := service.store.Reorder(context, input)
	if errors.Is(err, ErrRevisionConflict) {
		return Result{}, ErrRevisionConflict
	}
	if err != nil {
		return Result{}, err
	}
	return result, nil
}

func uniqueNonEmpty(ids []string) bool {
	seen := make(map[string]struct{}, len(ids))
	for _, id := range ids {
		if id == "" {
			return false
		}
		if _, duplicate := seen[id]; duplicate {
			return false
		}
		seen[id] = struct{}{}
	}
	return true
}
