package listmymentions

import (
	"context"
	"errors"
	"fmt"
	"time"
)

const (
	KindChannel       = "CHANNEL"
	KindDirectMessage = "DIRECT_MESSAGE"
)

var ErrInvalidInput = errors.New("invalid personal mentions input")

type Input struct {
	ActorID, Before string
	Limit           int
}
type Request struct {
	ActorID string
	Before  *Cursor
	Limit   int
}
type Mention struct {
	Kind, ID, ConversationID, AuthorID string
	CreatedAt                          time.Time
}
type Result struct {
	Mentions   []Mention
	NextCursor string
}
type Store interface {
	List(context.Context, Request) ([]Mention, error)
}
type Service struct{ store Store }

func New(store Store) Service { return Service{store: store} }

func (service Service) List(ctx context.Context, input Input) (Result, error) {
	if !validUUID(input.ActorID) || input.Limit < 1 || input.Limit > 100 {
		return Result{}, ErrInvalidInput
	}
	var before *Cursor
	if input.Before != "" {
		var err error
		before, err = decodeCursor(input.Before)
		if err != nil {
			return Result{}, ErrInvalidInput
		}
	}
	items, err := service.store.List(ctx, Request{ActorID: input.ActorID, Before: before, Limit: input.Limit})
	if err != nil {
		return Result{}, fmt.Errorf("list personal mentions: %w", err)
	}
	result := Result{Mentions: items}
	if len(items) > input.Limit {
		result.Mentions = items[:input.Limit]
		result.NextCursor, err = encodeCursor(result.Mentions[len(result.Mentions)-1])
		if err != nil {
			return Result{}, fmt.Errorf("encode personal mentions cursor: %w", err)
		}
	}
	return result, nil
}
