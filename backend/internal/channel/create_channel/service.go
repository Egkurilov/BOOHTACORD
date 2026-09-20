package createchannel

import (
	"context"
	"errors"
	"fmt"

	"voice-platform/backend/internal/channel/category_name"
)

var (
	ErrInvalidInput     = errors.New("invalid channel creation input")
	ErrCategoryNotFound = errors.New("category not found")
)

type Kind string

const (
	KindText  Kind = "TEXT"
	KindVoice Kind = "VOICE"
)

type Input struct {
	ActorID    string
	CategoryID string
	Name       string
	Kind       Kind
}

type Request struct {
	ID string
	Input
}

type Result struct {
	ID         string
	CategoryID string
	Name       string
	Kind       Kind
	Position   int
	Revision   int64
}

type Store interface {
	Create(context.Context, Request) (Result, error)
}

type Service struct {
	store Store
	newID func() (string, error)
}

func New(store Store) Service {
	return Service{store: store, newID: newChannelID}
}

func (service Service) Create(context context.Context, input Input) (Result, error) {
	if input.ActorID == "" || input.CategoryID == "" || categoryname.Validate(input.Name) != nil || (input.Kind != KindText && input.Kind != KindVoice) {
		return Result{}, ErrInvalidInput
	}
	id, err := service.newID()
	if err != nil {
		return Result{}, fmt.Errorf("create channel identifier: %w", err)
	}
	result, err := service.store.Create(context, Request{ID: id, Input: input})
	if errors.Is(err, ErrCategoryNotFound) {
		return Result{}, ErrCategoryNotFound
	}
	if err != nil {
		return Result{}, fmt.Errorf("persist channel: %w", err)
	}
	return result, nil
}
