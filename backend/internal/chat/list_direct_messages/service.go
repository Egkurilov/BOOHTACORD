package listdirectmessages

import (
	"context"
	"errors"
	"fmt"
	"time"
)

var ErrInvalidInput = errors.New("invalid direct message list input")

type Input struct{ ActorID string }
type Request struct{ Input }
type DirectMessage struct {
	ID, OtherParticipantID, OtherParticipantDisplayName string
	CreatedAt                                           time.Time
	UnreadCount                                         int64
}
type Result struct{ DirectMessages []DirectMessage }
type Store interface {
	List(context.Context, Request) ([]DirectMessage, error)
}
type Service struct{ store Store }

func New(store Store) Service { return Service{store: store} }
func (service Service) List(context context.Context, input Input) (Result, error) {
	if !validUUID(input.ActorID) {
		return Result{}, ErrInvalidInput
	}
	directMessages, err := service.store.List(context, Request{Input: input})
	if err != nil {
		return Result{}, fmt.Errorf("list direct messages: %w", err)
	}
	return Result{DirectMessages: directMessages}, nil
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
