package adminpostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"voice-platform/backend/internal/identity/admin_account"
	causal "voice-platform/backend/internal/observability/causal_reference"
	flowstage "voice-platform/backend/internal/observability/flow_stage"
)

const administrationLockKey int64 = 441903816

type Row interface {
	Scan(...any) error
}

type Transaction interface {
	Lock(context.Context, int64) error
	LockUser(context.Context, string) error
	QueryRow(context.Context, string, ...any) Row
	Commit(context.Context) error
	Rollback(context.Context) error
}

type Database interface {
	Begin(context.Context) (Transaction, error)
}

type Repository struct {
	database Database
}

func New(database Database) Repository {
	return Repository{database: database}
}

func (repository Repository) Update(context context.Context, input adminaccount.Input) (adminaccount.Account, error) {
	transaction, err := repository.database.Begin(context)
	if err != nil {
		return adminaccount.Account{}, fmt.Errorf("begin account administration: %w", err)
	}
	committed := false
	defer func() {
		if !committed {
			_ = transaction.Rollback(context)
		}
	}()
	if err := transaction.Lock(context, administrationLockKey); err != nil {
		return adminaccount.Account{}, fmt.Errorf("lock account administration: %w", err)
	}
	if err := transaction.LockUser(context, input.AccountID); err != nil {
		return adminaccount.Account{}, fmt.Errorf("lock target account: %w", err)
	}
	var account adminaccount.Account
	var role string
	var expected any
	if input.ExpectedUpdatedAt != "" {
		expected = input.ExpectedUpdatedAt
	}
	err = transaction.QueryRow(context, updateAccount, input.AccountID, string(input.Role), input.Blocked, input.ActorID, expected, causal.From(context).Bytes()).Scan(&account.ID, &role, &account.Blocked)
	if errors.Is(err, pgx.ErrNoRows) {
		if expected != nil {
			return adminaccount.Account{}, adminaccount.ErrRevisionConflict
		}
		return adminaccount.Account{}, adminaccount.ErrUpdateDenied
	}
	if err != nil {
		return adminaccount.Account{}, fmt.Errorf("update account administration: %w", err)
	}
	account.Role = adminaccount.Role(role)
	if err := transaction.Commit(context); err != nil {
		return adminaccount.Account{}, fmt.Errorf("commit account administration: %w", err)
	}
	committed = true
	flowstage.Mark(context, "commit", "success")
	return account, nil
}
