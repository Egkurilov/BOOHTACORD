package bootstrappostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"voice-platform/backend/internal/identity/bootstrap_administrator"
)

const bootstrapLockKey int64 = 728469151

const bootstrapStateStatus = `SELECT administrator_id IS NOT NULL FROM bootstrap_state WHERE singleton = TRUE FOR UPDATE`
const createAdministrator = `INSERT INTO users (id, login, display_name, role, password_hash) VALUES ($1, $2, $3, $4, $5)`
const createBootstrapState = `INSERT INTO bootstrap_state (singleton, administrator_id) VALUES (TRUE, $1)`
const auditInitialAdministrator = `INSERT INTO audit_events (event_type, target_user_id) VALUES ('INITIAL_ADMINISTRATOR_CREATED', $1)`

type Row interface {
	Scan(...any) error
}

type Transaction interface {
	Lock(context.Context, int64) error
	QueryRow(context.Context, string, ...any) Row
	Exec(context.Context, string, ...any) (pgconn.CommandTag, error)
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

func (repository Repository) CreateInitial(context context.Context, account bootstrapadministrator.Account) error {
	transaction, err := repository.database.Begin(context)
	if err != nil {
		return fmt.Errorf("begin administrator bootstrap: %w", err)
	}
	committed := false
	defer func() {
		if !committed {
			_ = transaction.Rollback(context)
		}
	}()
	if err := transaction.Lock(context, bootstrapLockKey); err != nil {
		return fmt.Errorf("lock administrator bootstrap: %w", err)
	}
	var initialized bool
	err = transaction.QueryRow(context, bootstrapStateStatus).Scan(&initialized)
	if err == nil {
		if initialized {
			return bootstrapadministrator.ErrAlreadyInitialized
		}
		return bootstrapadministrator.ErrBootstrapIncomplete
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return fmt.Errorf("read administrator bootstrap state: %w", err)
	}
	if _, err := transaction.Exec(context, createAdministrator, account.ID, account.Login, account.DisplayName, string(account.Role), account.PasswordHash); err != nil {
		return fmt.Errorf("create initial administrator: %w", err)
	}
	if _, err := transaction.Exec(context, createBootstrapState, account.ID); err != nil {
		return fmt.Errorf("link initial administrator bootstrap state: %w", err)
	}
	if _, err := transaction.Exec(context, auditInitialAdministrator, account.ID); err != nil {
		return fmt.Errorf("audit initial administrator: %w", err)
	}
	if err := transaction.Commit(context); err != nil {
		return fmt.Errorf("commit administrator bootstrap: %w", err)
	}
	committed = true
	return nil
}
