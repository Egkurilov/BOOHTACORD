package resetpostgres

import (
	"context"
	"fmt"

	"voice-platform/backend/internal/identity/create_password_reset"
)

const insertReset = `
WITH created AS (
    INSERT INTO password_resets (token_digest, user_id, expires_at)
    VALUES ($1, $2, $3)
    RETURNING user_id
), audited AS (
    INSERT INTO audit_events (actor_user_id, event_type, target_user_id)
    SELECT $4, 'PASSWORD_RESET_CREATED', user_id FROM created
)
SELECT user_id::text FROM created`

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

func (repository Repository) Create(context context.Context, request createpasswordreset.Request) error {
	var accountID string
	if err := repository.database.QueryRow(context, insertReset, request.TokenDigest[:], request.AccountID, request.ExpiresAt, request.ActorID).Scan(&accountID); err != nil {
		return fmt.Errorf("insert password reset: %w", err)
	}
	return nil
}
