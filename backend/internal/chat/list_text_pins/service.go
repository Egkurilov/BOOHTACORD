package listtextpins

import (
	"context"
	"errors"
	"github.com/google/uuid"
	"time"
)

var ErrInvalidInput = errors.New("invalid pin read input")
var ErrUnavailable = errors.New("pin conversation unavailable")

type Input struct {
	ActorID, ChannelID, Before string
	Limit                      int
}
type Cursor struct {
	ChannelID string    `json:"channel"`
	MessageID string    `json:"id"`
	PinnedAt  time.Time `json:"at"`
}
type Request struct {
	Input
	Cursor *Cursor
}
type Pin struct {
	MessageID        string    `json:"message_id"`
	PinnedAt         time.Time `json:"pinned_at"`
	AuthorID         string    `json:"author_id"`
	Preview          string    `json:"preview"`
	MessageCreatedAt time.Time `json:"message_created_at"`
}
type Result struct {
	Pins       []Pin  `json:"pins"`
	NextCursor string `json:"next_cursor,omitempty"`
	CanManage  bool   `json:"can_manage"`
}
type Store interface {
	List(context.Context, Request) ([]Pin, error)
}
type Service struct{ store Store }

func New(store Store) Service { return Service{store} }
func (s Service) List(ctx context.Context, in Input) (Result, error) {
	for _, id := range []string{in.ActorID, in.ChannelID} {
		if _, err := uuid.Parse(id); err != nil {
			return Result{}, ErrInvalidInput
		}
	}
	if in.Limit < 1 || in.Limit > 50 {
		return Result{}, ErrInvalidInput
	}
	cursor, err := decodeCursor(in.Before, in.ChannelID)
	if err != nil {
		return Result{}, err
	}
	pins, err := s.store.List(ctx, Request{Input: in, Cursor: cursor})
	if err != nil {
		return Result{}, err
	}
	result := Result{Pins: pins}
	if result.Pins == nil {
		result.Pins = []Pin{}
	}
	if len(pins) > in.Limit {
		result.Pins = pins[:in.Limit]
		last := result.Pins[in.Limit-1]
		result.NextCursor = encodeCursor(Cursor{in.ChannelID, last.MessageID, last.PinnedAt})
	}
	return result, nil
}
