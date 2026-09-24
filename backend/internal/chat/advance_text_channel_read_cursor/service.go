package advancetextchannelreadcursor

import (
	"context"
	"errors"
	"fmt"
	"time"
)

var (
	ErrChannelUnavailable = errors.New("text channel or message unavailable")
	ErrInvalidInput       = errors.New("invalid text channel read cursor input")
)

type Input struct{ ActorID, ChannelID, MessageID string }
type Request struct{ Input }
type Result struct {
	MessageID        string
	MessageCreatedAt time.Time
}
type Store interface {
	Advance(context.Context, Request) (Result, error)
}
type Service struct{ store Store }

func New(store Store) Service { return Service{store: store} }
func (service Service) Advance(context context.Context, input Input) (Result, error) {
	if !validUUID(input.ActorID) || !validUUID(input.ChannelID) || !validUUID(input.MessageID) {
		return Result{}, ErrInvalidInput
	}
	result, err := service.store.Advance(context, Request{Input: input})
	if errors.Is(err, ErrChannelUnavailable) {
		return Result{}, ErrChannelUnavailable
	}
	if err != nil {
		return Result{}, fmt.Errorf("advance text channel read cursor: %w", err)
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
