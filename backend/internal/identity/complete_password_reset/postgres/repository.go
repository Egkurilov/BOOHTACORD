package resetpostgres

import (
	"context"
	"crypto/sha256"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"voice-platform/backend/internal/identity/complete_password_reset"
)

const consumeReset = `
WITH consumed AS (
    UPDATE password_resets
    SET used_at = now()
    WHERE token_digest = $1
      AND used_at IS NULL
      AND expires_at > now()
    RETURNING user_id
), changed AS (
    UPDATE users
    SET password_hash = $2, updated_at = now()
    WHERE id IN (SELECT user_id FROM consumed)
    RETURNING id
), revoked AS (
    UPDATE sessions
    SET revoked_at = now()
    WHERE user_id IN (SELECT id FROM changed)
      AND revoked_at IS NULL
), revoked_leases AS (
    UPDATE voice_leases
    SET revoked_at = now(), revocation_reason = 'SESSION_REVOKED'
    WHERE user_id IN (SELECT id FROM changed)
    AND revoked_at IS NULL
    RETURNING id, channel_id
), queued AS (
    INSERT INTO voice_sfu_revocations (lease_id, channel_id)
    SELECT id, channel_id FROM revoked_leases
    ON CONFLICT (lease_id) DO NOTHING
), audited AS (
    INSERT INTO audit_events (event_type, target_user_id)
    SELECT 'PASSWORD_RESET_APPLIED', id FROM changed
)
SELECT id::text FROM changed`

type Row interface {
	Scan(...any) error
}

type Database interface {
	QueryRow(context.Context, string, ...any) Row
}

type Repository struct {
	database Database
}

func New(database Database) Repository {
	return Repository{database: database}
}

func (repository Repository) Consume(context context.Context, digest [sha256.Size]byte, passwordHash string) error {
	var accountID string
	err := repository.database.QueryRow(context, consumeReset, digest[:], passwordHash).Scan(&accountID)
	if errors.Is(err, pgx.ErrNoRows) {
		return completepasswordreset.ErrResetNotFound
	}
	if err != nil {
		return fmt.Errorf("consume reset: %w", err)
	}
	return nil
}
