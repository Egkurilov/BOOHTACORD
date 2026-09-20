package deletedirectmessage

import (
	"context"
	"errors"
	"fmt"
	"time"
)

var (
	ErrDeleteDenied = errors.New("direct message deletion denied")
	ErrInvalidInput = errors.New("invalid direct message deletion input")
)

type Input struct{ ActorID, DirectMessageID, MessageID string }
type Request struct{ Input }
type Result struct {
	ID, DirectMessageID string
	Revision            int
	DeletedAt           time.Time
}
type Store interface {
	Delete(context.Context, Request) (Result, error)
}
type Service struct{ store Store }

func New(store Store) Service { return Service{store: store} }
func (service Service) Delete(context context.Context, input Input) (Result, error) {
	if !validUUID(input.ActorID) || !validUUID(input.DirectMessageID) || !validUUID(input.MessageID) {
		return Result{}, ErrInvalidInput
	}
	result, err := service.store.Delete(context, Request{Input: input})
	if errors.Is(err, ErrDeleteDenied) {
		return Result{}, ErrDeleteDenied
	}
	if err != nil {
		return Result{}, fmt.Errorf("delete direct message: %w", err)
	}
	return result, nil
}

func validUUID(value string) bool {
	if len(value) != 36 {
		return false
	}
	for index, character := range value {
		if index == 8 || index == 13 || index == 18 || index == 23 {
			if character != '-' {
				return false
			}
			continue
		}
		if !((character >= '0' && character <= '9') || (character >= 'a' && character <= 'f') || (character >= 'A' && character <= 'F')) {
			return false
		}
	}
	return true
}
