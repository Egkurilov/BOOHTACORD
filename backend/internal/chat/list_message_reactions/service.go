package listmessagereactions

import (
	"context"
	"errors"
	"github.com/google/uuid"
)

var ErrInvalidInput = errors.New("invalid reaction read input")
var ErrUnavailable = errors.New("reaction conversation unavailable")

type Input struct {
	ActorID, ConversationID string
	MessageIDs              []string
	Direct                  bool
}
type Reaction struct {
	MessageID string `json:"message_id"`
	Emoji     string `json:"emoji"`
	Count     int    `json:"count"`
	Mine      bool   `json:"mine"`
}
type Store interface {
	List(context.Context, Input) ([]Reaction, error)
}
type Service struct{ store Store }

func New(store Store) Service { return Service{store} }
func (s Service) List(ctx context.Context, in Input) ([]Reaction, error) {
	if len(in.MessageIDs) < 1 || len(in.MessageIDs) > 100 {
		return nil, ErrInvalidInput
	}
	ids := append([]string{in.ActorID, in.ConversationID}, in.MessageIDs...)
	for _, id := range ids {
		if _, err := uuid.Parse(id); err != nil {
			return nil, ErrInvalidInput
		}
	}
	return s.store.List(ctx, in)
}
