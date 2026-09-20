package authorizetextattachmentpostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	authorizetextattachment "voice-platform/backend/internal/storage/authorize_text_attachment"
)

const selectTarget = `
SELECT 1
FROM users
JOIN channels ON channels.id = $2
WHERE users.id = $1
  AND users.blocked_at IS NULL
  AND channels.kind = 'TEXT'
  AND channels.archived_at IS NULL`

type Row interface{ Scan(...any) error }

type Database interface {
	QueryRow(context.Context, string, ...any) Row
}

type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }

func (repository Repository) Authorize(ctx context.Context, input authorizetextattachment.Input) error {
	var authorized int
	err := repository.database.QueryRow(ctx, selectTarget, input.ActorID, input.ChannelID).Scan(&authorized)
	if errors.Is(err, pgx.ErrNoRows) {
		return authorizetextattachment.ErrTargetUnavailable
	}
	if err != nil {
		return fmt.Errorf("select text attachment target: %w", err)
	}
	return nil
}
