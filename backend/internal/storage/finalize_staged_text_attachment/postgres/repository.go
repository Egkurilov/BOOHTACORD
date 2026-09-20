package finalizestagedtextattachmentpostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	finalize "voice-platform/backend/internal/storage/finalize_staged_text_attachment"
)

const insertAttachment = `
WITH target AS (
    SELECT channels.id
    FROM users
    JOIN channels ON channels.id = $3
    WHERE users.id = $2
      AND users.blocked_at IS NULL
      AND channels.kind = 'TEXT'
      AND channels.archived_at IS NULL
), inserted AS (
    INSERT INTO attachments (id, owner_id, channel_id, original_name, storage_key, byte_size, state)
    SELECT $1, $2, target.id, $4, $5, $6, 'UNATTACHED'
    FROM target
    RETURNING id::text, owner_id::text, channel_id::text, original_name, storage_key::text, byte_size
)
SELECT * FROM inserted`

type Row interface{ Scan(...any) error }
type Database interface {
	QueryRow(context.Context, string, ...any) Row
}
type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }

func (repository Repository) Create(ctx context.Context, request finalize.Request) (finalize.Result, error) {
	var result finalize.Result
	err := repository.database.QueryRow(ctx, insertAttachment, request.ID, request.ActorID, request.ChannelID, request.OriginalName, request.StorageKey, request.SizeBytes).Scan(
		&result.ID, &result.OwnerID, &result.ChannelID, &result.OriginalName, &result.StorageKey, &result.SizeBytes,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return finalize.Result{}, finalize.ErrTargetUnavailable
	}
	if err != nil {
		return finalize.Result{}, fmt.Errorf("insert unattached text attachment: %w", err)
	}
	return result, nil
}
