package recoverlastadministratoraccesspostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"voice-platform/backend/internal/identity/recover_last_administrator_access"
)

// Recovery must serialize with administrator role changes.
const recoveryLockKey int64 = 441903816

const recoverSoleActiveAdministrator = `
WITH recovered AS (
    UPDATE users
    SET password_hash = $2,
        updated_at = now()
    WHERE login = $1
      AND role = 'ADMINISTRATOR'
      AND blocked_at IS NULL
      AND (SELECT count(*) FROM users WHERE role = 'ADMINISTRATOR' AND blocked_at IS NULL) = 1
    RETURNING id
), revoked AS (
    UPDATE sessions
    SET revoked_at = now()
    WHERE user_id IN (SELECT id FROM recovered)
      AND revoked_at IS NULL
), revoked_leases AS (
    UPDATE voice_leases
    SET revoked_at = now(), revocation_reason = 'SESSION_REVOKED'
    WHERE user_id IN (SELECT id FROM recovered)
      AND revoked_at IS NULL
    RETURNING id, channel_id
), queued AS (
    INSERT INTO voice_sfu_revocations (lease_id, channel_id)
    SELECT id, channel_id FROM revoked_leases
    ON CONFLICT (lease_id) DO NOTHING
), audited AS (
    INSERT INTO audit_events (event_type, target_user_id)
    SELECT 'LAST_ADMINISTRATOR_ACCESS_RECOVERED', id FROM recovered
)
SELECT id::text FROM recovered`

type Row interface {
	Scan(...any) error
}

type Transaction interface {
	Lock(context.Context, int64) error
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

func (repository Repository) RecoverSoleActiveAdministrator(context context.Context, login, passwordHash string) error {
	transaction, err := repository.database.Begin(context)
	if err != nil {
		return fmt.Errorf("begin sole administrator access recovery: %w", err)
	}
	committed := false
	defer func() {
		if !committed {
			_ = transaction.Rollback(context)
		}
	}()
	if err := transaction.Lock(context, recoveryLockKey); err != nil {
		return fmt.Errorf("lock sole administrator access recovery: %w", err)
	}
	var accountID string
	err = transaction.QueryRow(context, recoverSoleActiveAdministrator, login, passwordHash).Scan(&accountID)
	if errors.Is(err, pgx.ErrNoRows) {
		return recoverlastadministratoraccess.ErrRecoveryUnavailable
	}
	if err != nil {
		return fmt.Errorf("recover sole active administrator access: %w", err)
	}
	if err := transaction.Commit(context); err != nil {
		return fmt.Errorf("commit sole administrator access recovery: %w", err)
	}
	committed = true
	return nil
}
