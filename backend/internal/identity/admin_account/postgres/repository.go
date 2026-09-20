package adminpostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"voice-platform/backend/internal/identity/admin_account"
)

const administrationLockKey int64 = 441903816

const updateAccount = `
WITH updated AS (
    UPDATE users
    SET role = $2,
        blocked_at = CASE WHEN $3 THEN COALESCE(blocked_at, now()) ELSE NULL END,
        updated_at = now()
    WHERE id = $1
      AND NOT (
          role = 'ADMINISTRATOR'
          AND blocked_at IS NULL
          AND ($2 <> 'ADMINISTRATOR' OR $3)
          AND NOT EXISTS (
              SELECT 1 FROM users
              WHERE role = 'ADMINISTRATOR'
                AND blocked_at IS NULL
                AND id <> $1
          )
      )
    RETURNING id, role, blocked_at IS NOT NULL AS blocked
), revoked AS (
    UPDATE sessions
    SET revoked_at = now()
    WHERE user_id IN (SELECT id FROM updated)
      AND $3
      AND revoked_at IS NULL
), revoked_leases AS (
    UPDATE voice_leases
    SET revoked_at = now(), revocation_reason = 'BANNED'
    WHERE user_id IN (SELECT id FROM updated)
      AND $3
      AND revoked_at IS NULL
    RETURNING id, channel_id
), queued AS (
    INSERT INTO voice_sfu_revocations (lease_id, channel_id)
    SELECT id, channel_id FROM revoked_leases
    ON CONFLICT (lease_id) DO NOTHING
), audited AS (
    INSERT INTO audit_events (actor_user_id, event_type, target_user_id)
    SELECT $4, 'ACCOUNT_ADMIN_STATE_UPDATED', id FROM updated
)
SELECT id::text, role, blocked FROM updated`

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
	err = transaction.QueryRow(context, updateAccount, input.AccountID, string(input.Role), input.Blocked, input.ActorID).Scan(&account.ID, &role, &account.Blocked)
	if errors.Is(err, pgx.ErrNoRows) {
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
	return account, nil
}
