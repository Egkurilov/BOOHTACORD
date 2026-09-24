package authorizedirectmessageattachment

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
)

var (
	ErrInvalidInput      = errors.New("invalid direct message attachment target")
	ErrTargetUnavailable = errors.New("direct message attachment target unavailable")
)

type Input struct{ ActorID, DirectMessageID string }
type Store interface {
	Authorize(context.Context, Input) error
}
type Service struct{ store Store }

func New(store Store) Service { return Service{store: store} }

func (service Service) Authorize(ctx context.Context, input Input) error {
	if !validUUID(input.ActorID) || !validUUID(input.DirectMessageID) {
		return ErrInvalidInput
	}
	if err := service.store.Authorize(ctx, input); errors.Is(err, ErrTargetUnavailable) {
		return ErrTargetUnavailable
	} else if err != nil {
		return fmt.Errorf("authorize direct message attachment target: %w", err)
	}
	return nil
}

func validUUID(value string) bool { _, err := uuid.Parse(value); return err == nil && len(value) == 36 }
