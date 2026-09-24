package advancetextchannelreadcursorpostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	advancetextchannelreadcursor "voice-platform/backend/internal/chat/advance_text_channel_read_cursor"
)

const advanceTextChannelReadCursor = `
WITH visible_message AS (
    SELECT message.id, message.created_at
    FROM channels AS channel
    JOIN messages AS message
      ON message.channel_id = channel.id
     AND message.id = $3::uuid
     AND message.deleted_at IS NULL
    WHERE channel.id = $2::uuid
      AND channel.kind = 'TEXT'
      AND channel.archived_at IS NULL
    FOR SHARE OF channel
), upserted AS (
    INSERT INTO channel_read_cursors (account_id, channel_id, message_id, message_created_at)
    SELECT $1::uuid, $2::uuid, visible_message.id, visible_message.created_at FROM visible_message
    ON CONFLICT (account_id, channel_id) DO UPDATE
    SET message_id = CASE WHEN (channel_read_cursors.message_created_at, channel_read_cursors.message_id)
            < (EXCLUDED.message_created_at, EXCLUDED.message_id) THEN EXCLUDED.message_id ELSE channel_read_cursors.message_id END,
        message_created_at = CASE WHEN (channel_read_cursors.message_created_at, channel_read_cursors.message_id)
            < (EXCLUDED.message_created_at, EXCLUDED.message_id) THEN EXCLUDED.message_created_at ELSE channel_read_cursors.message_created_at END,
        updated_at = CASE WHEN (channel_read_cursors.message_created_at, channel_read_cursors.message_id)
            < (EXCLUDED.message_created_at, EXCLUDED.message_id) THEN now() ELSE channel_read_cursors.updated_at END
    RETURNING message_id::text, message_created_at
)
SELECT message_id, message_created_at FROM upserted`

type Row interface{ Scan(...any) error }
type Database interface {
	QueryRow(context.Context, string, ...any) Row
}
type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }
func (repository Repository) Advance(context context.Context, request advancetextchannelreadcursor.Request) (advancetextchannelreadcursor.Result, error) {
	var result advancetextchannelreadcursor.Result
	err := repository.database.QueryRow(context, advanceTextChannelReadCursor, request.ActorID, request.ChannelID, request.MessageID).Scan(&result.MessageID, &result.MessageCreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return advancetextchannelreadcursor.Result{}, advancetextchannelreadcursor.ErrChannelUnavailable
	}
	if err != nil {
		return advancetextchannelreadcursor.Result{}, fmt.Errorf("advance text channel read cursor: %w", err)
	}
	return result, nil
}
