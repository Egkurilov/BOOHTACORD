package avatarpostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"voice-platform/backend/internal/identity/upload_own_avatar"
)

const replaceAvatar = `
WITH locked AS MATERIALIZED (
    SELECT COALESCE(avatar_key, '') AS avatar_key FROM users
    WHERE id = $1 AND blocked_at IS NULL FOR UPDATE
), updated AS (
    UPDATE users SET avatar_key = $2, updated_at = now()
    WHERE id = $1 AND blocked_at IS NULL RETURNING id
)
SELECT locked.avatar_key FROM locked JOIN updated ON TRUE`

const clearAvatar = `
WITH locked AS MATERIALIZED (
    SELECT COALESCE(avatar_key, '') AS avatar_key FROM users
    WHERE id = $1 AND blocked_at IS NULL FOR UPDATE
), updated AS (
    UPDATE users SET avatar_key = NULL, updated_at = now()
    WHERE id = $1 AND blocked_at IS NULL RETURNING id
)
SELECT locked.avatar_key FROM locked JOIN updated ON TRUE`

type Row = pgx.Row
type Database interface {
	QueryRow(context.Context, string, ...any) Row
}
type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }

func (repository Repository) ReplaceAvatarKey(ctx context.Context, accountID, key string) (string, error) {
	var oldKey string
	err := repository.database.QueryRow(ctx, replaceAvatar, accountID, key).Scan(&oldKey)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", uploadownavatar.ErrProfileUnavailable
	}
	if err != nil {
		return "", fmt.Errorf("replace account avatar: %w", err)
	}
	return oldKey, nil
}

func (repository Repository) ClearAvatarKey(ctx context.Context, accountID string) (string, error) {
	var oldKey string
	err := repository.database.QueryRow(ctx, clearAvatar, accountID).Scan(&oldKey)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", uploadownavatar.ErrProfileUnavailable
	}
	if err != nil {
		return "", fmt.Errorf("clear account avatar: %w", err)
	}
	return oldKey, nil
}

func (repository Repository) FindAvatarKey(ctx context.Context, accountID string) (string, error) {
	var key string
	err := repository.database.QueryRow(ctx, `SELECT avatar_key FROM users WHERE id = $1 AND blocked_at IS NULL AND avatar_key IS NOT NULL`, accountID).Scan(&key)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", uploadownavatar.ErrAvatarNotFound
	}
	if err != nil {
		return "", fmt.Errorf("find member avatar: %w", err)
	}
	return key, nil
}
