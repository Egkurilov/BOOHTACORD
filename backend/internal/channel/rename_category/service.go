package renamecategory

import (
	"context"
	"errors"

	"voice-platform/backend/internal/channel/category_name"
)

var (
	ErrInvalidInput     = errors.New("invalid category rename input")
	ErrRevisionConflict = errors.New("category topology revision conflict")
)

type Input struct {
	ActorID          string
	CategoryID       string
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

type Service struct {
	store Store
}

func New(store Store) Service {
	return Service{store: store}
}

func (service Service) Rename(context context.Context, input Input) (Result, error) {
	if input.ActorID == "" || input.CategoryID == "" || input.ExpectedRevision < 1 || categoryname.Validate(input.Name) != nil {
		return Result{}, ErrInvalidInput
	}
	result, err := service.store.Rename(context, input)
	if errors.Is(err, ErrRevisionConflict) {
		return Result{}, ErrRevisionConflict
	}
	if err != nil {
		return Result{}, err
	}
	return result, nil
}
