package deletetextmessagepostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	deletetextmessage "voice-platform/backend/internal/chat/delete_text_message"
)

const deleteMessage = `
WITH channel AS (
    SELECT id FROM channels WHERE id = $2 AND kind = 'TEXT' AND archived_at IS NULL
), changed AS (
    UPDATE messages AS message
    SET body = '', deleted_at = now(), revision = message.revision + 1
    FROM channel
    WHERE message.id = $1
      AND message.channel_id = channel.id
      AND message.deleted_at IS NULL
      AND (message.author_id = $3 OR $4 = 'ADMINISTRATOR')
    RETURNING message.id, message.channel_id, message.author_id, message.revision, message.deleted_at
), audited AS (
    INSERT INTO audit_events (actor_user_id, event_type, target_user_id, metadata)
    SELECT $3, 'TEXT_MESSAGE_DELETED', changed.author_id,
           jsonb_build_object('channel_id', changed.channel_id::text, 'message_id', changed.id::text)
    FROM changed
)
SELECT id::text, channel_id::text, revision, deleted_at FROM changed`

type Row interface{ Scan(...any) error }
type Database interface {
	QueryRow(context.Context, string, ...any) Row
}
type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }
func (repository Repository) Delete(context context.Context, request deletetextmessage.Request) (deletetextmessage.Result, error) {
	var result deletetextmessage.Result
	err := repository.database.QueryRow(context, deleteMessage, request.MessageID, request.ChannelID, request.ActorID, request.ActorRole).Scan(&result.ID, &result.ChannelID, &result.Revision, &result.DeletedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return deletetextmessage.Result{}, deletetextmessage.ErrDeleteDenied
	}
	if err != nil {
		return deletetextmessage.Result{}, fmt.Errorf("delete text message: %w", err)
	}
	return result, nil
}
