package advancedirectmessagereadcursorpostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	advancedirectmessagereadcursor "voice-platform/backend/internal/chat/advance_direct_message_read_cursor"
)

const advanceDirectMessageReadCursor = `
WITH visible_message AS (
    SELECT message.id, message.created_at
    FROM direct_messages dm
    JOIN direct_message_messages message
      ON message.id = $3
     AND message.direct_message_id = dm.id
    WHERE dm.id = $2
      AND $1::uuid IN (dm.participant_one_id, dm.participant_two_id)
), upserted AS (
    INSERT INTO direct_message_read_cursors (account_id, direct_message_id, message_id, message_created_at)
    SELECT $1, $2, visible_message.id, visible_message.created_at FROM visible_message
    ON CONFLICT (account_id, direct_message_id) DO UPDATE
    SET message_id = CASE WHEN (direct_message_read_cursors.message_created_at, direct_message_read_cursors.message_id)
            < (EXCLUDED.message_created_at, EXCLUDED.message_id) THEN EXCLUDED.message_id ELSE direct_message_read_cursors.message_id END,
        message_created_at = CASE WHEN (direct_message_read_cursors.message_created_at, direct_message_read_cursors.message_id)
            < (EXCLUDED.message_created_at, EXCLUDED.message_id) THEN EXCLUDED.message_created_at ELSE direct_message_read_cursors.message_created_at END,
        updated_at = CASE WHEN (direct_message_read_cursors.message_created_at, direct_message_read_cursors.message_id)
            < (EXCLUDED.message_created_at, EXCLUDED.message_id) THEN now() ELSE direct_message_read_cursors.updated_at END
    RETURNING message_id::text, message_created_at
)
SELECT message_id, message_created_at FROM upserted`

type Row interface{ Scan(...any) error }
type Database interface {
	QueryRow(context.Context, string, ...any) Row
}
type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }
func (repository Repository) Advance(context context.Context, request advancedirectmessagereadcursor.Request) (advancedirectmessagereadcursor.Result, error) {
	var result advancedirectmessagereadcursor.Result
	err := repository.database.QueryRow(context, advanceDirectMessageReadCursor, request.ActorID, request.DirectMessageID, request.MessageID).Scan(&result.MessageID, &result.MessageCreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return advancedirectmessagereadcursor.Result{}, advancedirectmessagereadcursor.ErrDirectMessageUnavailable
	}
	if err != nil {
		return advancedirectmessagereadcursor.Result{}, fmt.Errorf("advance direct message read cursor: %w", err)
	}
	return result, nil
}
