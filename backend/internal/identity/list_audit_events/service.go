package listauditevents

import (
	"context"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"
)

const defaultLimit = 50
const maxLimit = 100

var ErrInvalidInput = errors.New("invalid audit page")

type Input struct {
	Before string
	Limit  int
}
type Event struct {
	ID        string    `json:"id"`
	ActorID   string    `json:"actor_user_id,omitempty"`
	EventType string    `json:"event_type"`
	TargetID  string    `json:"target_user_id,omitempty"`
	CreatedAt time.Time `json:"created_at"`
}
type Result struct {
	Events     []Event `json:"events"`
	NextCursor string  `json:"next_cursor,omitempty"`
}
type Store interface {
	List(context.Context, int64, int) ([]Event, error)
}
type Service struct{ store Store }

func New(store Store) Service { return Service{store: store} }

func (service Service) List(ctx context.Context, input Input) (Result, error) {
	if input.Limit < 0 || input.Limit > maxLimit {
		return Result{}, ErrInvalidInput
	}
	limit := input.Limit
	if limit == 0 {
		limit = defaultLimit
	}
	var before int64
	var err error
	if input.Before != "" {
		if strings.Trim(input.Before, "0123456789") != "" { return Result{}, ErrInvalidInput }
		before, err = strconv.ParseInt(input.Before, 10, 64)
		if err != nil || before < 1 {
			return Result{}, ErrInvalidInput
		}
	}
	events, err := service.store.List(ctx, before, limit+1)
	if err != nil {
		return Result{}, fmt.Errorf("list audit events: %w", err)
	}
	result := Result{Events: append([]Event{}, events...)}
	if len(events) > limit {
		result.Events = events[:limit]
		result.NextCursor = result.Events[len(result.Events)-1].ID
	}
	return result, nil
}
