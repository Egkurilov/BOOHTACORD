package finalizestageddirectmessageattachmentpostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	finalize "voice-platform/backend/internal/storage/finalize_staged_direct_message_attachment"
)

const insertAttachment = `
WITH target AS (
    SELECT dm.id FROM direct_messages dm
    JOIN users one ON one.id = dm.participant_one_id
    JOIN users two ON two.id = dm.participant_two_id
    WHERE dm.id = $3
      AND $2::uuid IN (dm.participant_one_id, dm.participant_two_id)
      AND one.blocked_at IS NULL AND two.blocked_at IS NULL
    FOR SHARE OF one, two
), inserted AS (
    INSERT INTO attachments (id, owner_id, direct_message_id, original_name, storage_key, byte_size, state)
    SELECT $1, $2, target.id, $4, $5, $6, 'UNATTACHED' FROM target
    RETURNING id::text, owner_id::text, direct_message_id::text, original_name, storage_key::text, byte_size
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
	err := repository.database.QueryRow(ctx, insertAttachment, request.ID, request.ActorID, request.DirectMessageID, request.OriginalName, request.StorageKey, request.SizeBytes).Scan(&result.ID, &result.OwnerID, &result.DirectMessageID, &result.OriginalName, &result.StorageKey, &result.SizeBytes)
	if errors.Is(err, pgx.ErrNoRows) {
		return finalize.Result{}, finalize.ErrTargetUnavailable
	}
	if err != nil {
		return finalize.Result{}, fmt.Errorf("insert unattached direct message attachment: %w", err)
	}
	return result, nil
}
