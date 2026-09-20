package authorizetextattachment

import (
	"context"
	"errors"
	"fmt"
)

var (
	ErrInvalidInput      = errors.New("invalid text attachment target")
	ErrTargetUnavailable = errors.New("text attachment target unavailable")
)

type Input struct{ ActorID, ChannelID string }

type Store interface {
	Authorize(context.Context, Input) error
}

type Service struct{ store Store }

func New(store Store) Service { return Service{store: store} }

func (service Service) Authorize(ctx context.Context, input Input) error {
	if !validUUID(input.ActorID) || !validUUID(input.ChannelID) {
		return ErrInvalidInput
	}
	if err := service.store.Authorize(ctx, input); errors.Is(err, ErrTargetUnavailable) {
		return ErrTargetUnavailable
	} else if err != nil {
		return fmt.Errorf("authorize text attachment target: %w", err)
	}
	return nil
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
