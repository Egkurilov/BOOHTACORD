package dispatchvoicesfurevocation

import (
	"context"
	"errors"
	"fmt"
)

var ErrPending = errors.New("voice sfu revocation pending")

type Store interface {
	Claim(context.Context, int) ([]Item, error)
	Confirm(context.Context, Item) error
	Retry(context.Context, Item, string) error
}

type Remover interface {
	Remove(context.Context, string, string) error
}

type Result struct {
	Confirmed int
	Pending   int
}

type Service struct {
	store   Store
	remover Remover
}

func New(store Store, remover Remover) Service { return Service{store: store, remover: remover} }

func (service Service) Dispatch(context context.Context, limit int) (Result, error) {
	items, err := service.store.Claim(context, limit)
	if err != nil {
		return Result{}, fmt.Errorf("claim voice sfu revocations: %w", err)
	}
	var result Result
	for _, item := range items {
		confirmed, err := service.attempt(context, item)
		if err != nil {
			return result, fmt.Errorf("process voice sfu revocation: %w", err)
		}
		if confirmed {
			result.Confirmed++
		} else {
			result.Pending++
		}
	}
	if result.Pending > 0 {
		return result, ErrPending
	}
	return result, nil
}
