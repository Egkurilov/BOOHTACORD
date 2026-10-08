package listarchivedtext

import (
	"context"
	"errors"
	"github.com/google/uuid"
	"time"
)

var ErrInvalidInput = errors.New("invalid archive page input")

type Input struct {
	ActorID, Cursor string
	Limit           int
}
type Channel struct {
	ID           string    `json:"id"`
	Name         string    `json:"name"`
	Description  string    `json:"description"`
	CategoryName string    `json:"category_name"`
	ArchivedAt   time.Time `json:"archived_at"`
}
type Result struct {
	Revision   int64     `json:"revision"`
	Channels   []Channel `json:"channels"`
	NextCursor string    `json:"next_cursor,omitempty"`
	CanManage  bool      `json:"can_manage"`
}
type Store interface {
	List(context.Context, Input) (Result, error)
}
type Service struct{ store Store }

func New(store Store) Service { return Service{store} }
func (s Service) List(ctx context.Context, in Input) (Result, error) {
	if _, err := uuid.Parse(in.ActorID); err != nil {
		return Result{}, ErrInvalidInput
	}
	if in.Cursor != "" {
		if _, err := uuid.Parse(in.Cursor); err != nil {
			return Result{}, ErrInvalidInput
		}
	}
	if in.Limit < 1 || in.Limit > 100 {
		return Result{}, ErrInvalidInput
	}
	result, err := s.store.List(ctx, in)
	if err != nil {
		return Result{}, err
	}
	if len(result.Channels) > in.Limit {
		result.Channels = result.Channels[:in.Limit]
		result.NextCursor = result.Channels[in.Limit-1].ID
	}
	return result, nil
}
