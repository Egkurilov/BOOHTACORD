package logoutpostgres

import (
	"context"
	"crypto/sha256"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
)

const selectActiveSessionOwner = `
SELECT user_id::text FROM sessions
WHERE token_digest = $1 AND revoked_at IS NULL`
const revokeSessionAndLease = `
WITH revoked_session AS (
    UPDATE sessions SET revoked_at = now()
    WHERE token_digest = $1 AND revoked_at IS NULL
    RETURNING token_digest
), revoked_leases AS (
    UPDATE voice_leases
    SET revoked_at = now(), revocation_reason = 'LOGOUT'
    WHERE session_token_digest IN (SELECT token_digest FROM revoked_session)
      AND revoked_at IS NULL
    RETURNING id, channel_id
)
INSERT INTO voice_sfu_revocations (lease_id, channel_id)
SELECT id, channel_id FROM revoked_leases
ON CONFLICT (lease_id) DO NOTHING`

type Row interface{ Scan(...any) error }
type Transaction interface {
	QueryRow(context.Context, string, ...any) Row
	LockUser(context.Context, string) error
	Exec(context.Context, string, ...any) error
	Commit(context.Context) error
	Rollback(context.Context) error
}
type Database interface {
	Begin(context.Context) (Transaction, error)
}
type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }

func (repository Repository) Revoke(context context.Context, digest [sha256.Size]byte) error {
	transaction, err := repository.database.Begin(context)
	if err != nil {
		return fmt.Errorf("begin logout: %w", err)
	}
	committed := false
	defer func() {
		if !committed {
			_ = transaction.Rollback(context)
		}
	}()
	var userID string
	err = transaction.QueryRow(context, selectActiveSessionOwner, digest[:]).Scan(&userID)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("find logout session owner: %w", err)
	}
	if err := transaction.LockUser(context, userID); err != nil {
		return fmt.Errorf("lock logout account: %w", err)
	}
	if err := transaction.Exec(context, revokeSessionAndLease, digest[:]); err != nil {
		return fmt.Errorf("revoke session and voice lease: %w", err)
	}
	if err := transaction.Commit(context); err != nil {
		return fmt.Errorf("commit logout: %w", err)
	}
	committed = true
	return nil
}
