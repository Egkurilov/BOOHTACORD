package opendirectmessage

import (
	"context"
	"errors"
	"fmt"
	"time"
)

var (
	ErrInvalidInput           = errors.New("invalid direct message input")
	ErrParticipantUnavailable = errors.New("direct message participant unavailable")
)

type Input struct{ ActorID, ParticipantID string }
type Request struct {
	ID string
	Input
}
type Result struct {
	ID, ParticipantOneID, ParticipantTwoID string
	CreatedAt                              time.Time
}
type Store interface {
	Open(context.Context, Request) (Result, error)
}
type Service struct {
	store Store
	newID func() (string, error)
}

func New(store Store) Service { return Service{store: store, newID: newDirectMessageID} }

func (service Service) Open(context context.Context, input Input) (Result, error) {
	if !validUUID(input.ActorID) || !validUUID(input.ParticipantID) || input.ActorID == input.ParticipantID {
		return Result{}, ErrInvalidInput
	}
	id, err := service.newID()
	if err != nil {
		return Result{}, fmt.Errorf("create direct message identifier: %w", err)
	}
	result, err := service.store.Open(context, Request{ID: id, Input: input})
	if errors.Is(err, ErrParticipantUnavailable) {
		return Result{}, ErrParticipantUnavailable
	}
	if err != nil {
		return Result{}, fmt.Errorf("persist direct message: %w", err)
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
