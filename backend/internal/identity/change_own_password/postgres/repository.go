package changepasswordpostgres

import (
	"context"
	"crypto/sha256"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	changeownpassword "voice-platform/backend/internal/identity/change_own_password"
)

const changePassword = `
WITH changed AS (
    UPDATE users SET password_hash = $2, updated_at = now()
    WHERE id = $1 AND password_hash = $3
    RETURNING id
), revoked AS (
    UPDATE sessions SET revoked_at = now()
    WHERE user_id IN (SELECT id FROM changed)
      AND token_digest <> $4 AND revoked_at IS NULL
), revoked_leases AS (
    UPDATE voice_leases SET revoked_at = now(), revocation_reason = 'SESSION_REVOKED'
    WHERE user_id IN (SELECT id FROM changed)
      AND session_token_digest <> $4 AND revoked_at IS NULL
    RETURNING id, channel_id
), queued AS (
    INSERT INTO voice_sfu_revocations (lease_id, channel_id)
    SELECT id, channel_id FROM revoked_leases ON CONFLICT (lease_id) DO NOTHING
), audited AS (
    INSERT INTO audit_events (actor_user_id, event_type, target_user_id)
    SELECT id, 'PASSWORD_CHANGED', id FROM changed
)
SELECT id::text FROM changed`

type Row interface{ Scan(...any) error }
type Database interface {
	QueryRow(context.Context, string, ...any) Row
}
type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }

func (repository Repository) FindPasswordHash(ctx context.Context, accountID string) (string, error) {
	var hash string
	if err := repository.database.QueryRow(ctx, `SELECT password_hash FROM users WHERE id = $1 AND blocked_at IS NULL`, accountID).Scan(&hash); err != nil {
		return "", fmt.Errorf("read password hash: %w", err)
	}
	return hash, nil
}

func (repository Repository) ChangePassword(ctx context.Context, accountID, currentHash, newHash string, digest [sha256.Size]byte) error {
	var changedID string
	err := repository.database.QueryRow(ctx, changePassword, accountID, newHash, currentHash, digest[:]).Scan(&changedID)
	if errors.Is(err, pgx.ErrNoRows) {
		return changeownpassword.ErrCredentialChanged
	}
	if err != nil {
		return fmt.Errorf("persist password change: %w", err)
	}
	return nil
}
