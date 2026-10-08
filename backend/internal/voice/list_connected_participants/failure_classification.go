package listconnectedparticipants

import (
	"context"
	"errors"
)

func (service Service) observeFailure(stage string) {
	if service.observer != nil {
		service.observer.ObserveVoiceRosterFailure(stage)
	}
}

func (service Service) observeOperationFailure(ctx context.Context, err error, stage string) {
	if errors.Is(ctx.Err(), context.Canceled) {
		return
	}
	if errors.Is(ctx.Err(), context.DeadlineExceeded) || errors.Is(err, context.DeadlineExceeded) {
		stage += "_timeout"
	} else if errors.Is(err, context.Canceled) {
		stage += "_canceled"
	}
	service.observeFailure(stage)
}
