package createcategory

import (
	"context"
	"errors"
	"fmt"

	"voice-platform/backend/internal/channel/category_name"
)

var ErrInvalidInput = errors.New("invalid category creation input")

type Input struct {
	ActorID string
	Name    string
}

type Request struct {
	ID      string
	ActorID string
	Name    string
}

type Result struct {
	ID       string
	Name     string
	Position int
	Revision int64
}

type Store interface {
	Create(context.Context, Request) (Result, error)
}

type Service struct {
	store Store
	newID func() (string, error)
}

func New(store Store) Service {
	return Service{store: store, newID: newCategoryID}
}

func (service Service) Create(context context.Context, input Input) (Result, error) {
	if input.ActorID == "" || categoryname.Validate(input.Name) != nil {
		return Result{}, ErrInvalidInput
	}
	id, err := service.newID()
	if err != nil {
		return Result{}, fmt.Errorf("create category identifier: %w", err)
	}
	result, err := service.store.Create(context, Request{ID: id, ActorID: input.ActorID, Name: input.Name})
	if err != nil {
		return Result{}, fmt.Errorf("persist category: %w", err)
	}
	return result, nil
}
