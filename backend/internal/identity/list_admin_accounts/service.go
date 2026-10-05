package listadminaccounts

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
)

const defaultLimit = 50
const maxLimit = 100

var ErrInvalidInput = errors.New("invalid administrator account page")

type Input struct {
	Cursor string
	Limit  int
}
type Account struct {
	ID          string    `json:"account_id"`
	Login       string    `json:"login"`
	DisplayName string    `json:"display_name"`
	Role        string    `json:"role"`
	Blocked     bool      `json:"blocked"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}
type Result struct {
	Accounts   []Account `json:"accounts"`
	NextCursor string    `json:"next_cursor,omitempty"`
}
type Store interface {
	List(context.Context, string, int) ([]Account, error)
}
type Service struct{ store Store }

func New(store Store) Service { return Service{store: store} }

func (service Service) List(ctx context.Context, input Input) (Result, error) {
	if input.Limit < 0 || input.Limit > maxLimit || (input.Cursor != "" && !validUUID(input.Cursor)) {
		return Result{}, ErrInvalidInput
	}
	limit := input.Limit
	if limit == 0 {
		limit = defaultLimit
	}
	accounts, err := service.store.List(ctx, input.Cursor, limit+1)
	if err != nil {
		return Result{}, fmt.Errorf("list admin accounts: %w", err)
	}
	result := Result{Accounts: append([]Account{}, accounts...)}
	if len(accounts) > limit {
		result.Accounts = accounts[:limit]
		result.NextCursor = result.Accounts[len(result.Accounts)-1].ID
	}
	return result, nil
}

func validUUID(value string) bool { _, err := uuid.Parse(value); return err == nil }
