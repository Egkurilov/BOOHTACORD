package editdirectmessagepostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	editdirectmessage "voice-platform/backend/internal/chat/edit_direct_message"
)

const updateDirectMessage = `
WITH writable_pair AS (
    SELECT dm.id FROM direct_messages dm
    WHERE dm.id = $2
      AND $3::uuid IN (dm.participant_one_id, dm.participant_two_id)
)
UPDATE direct_message_messages AS message
SET body = $4, edited_at = now(), revision = message.revision + 1
FROM writable_pair
WHERE message.id = $1
  AND message.direct_message_id = writable_pair.id
  AND message.author_id = $3
  AND message.deleted_at IS NULL
  AND message.revision = $5
RETURNING message.id::text, message.direct_message_id::text, message.author_id::text, message.client_message_id::text,
          message.body, COALESCE(message.reply_to_id::text, ''), message.revision, message.created_at, message.edited_at`

type Row interface{ Scan(...any) error }
type Database interface {
	QueryRow(context.Context, string, ...any) Row
}
type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }
func (repository Repository) Edit(context context.Context, request editdirectmessage.Request) (editdirectmessage.Result, error) {
	var result editdirectmessage.Result
	err := repository.database.QueryRow(context, updateDirectMessage, request.MessageID, request.DirectMessageID, request.ActorID, request.Body, request.ExpectedRevision).Scan(
		&result.ID, &result.DirectMessageID, &result.AuthorID, &result.ClientMessageID, &result.Body, &result.ReplyToID, &result.Revision, &result.CreatedAt, &result.EditedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return editdirectmessage.Result{}, editdirectmessage.ErrConflict
	}
	if err != nil {
		return editdirectmessage.Result{}, fmt.Errorf("update direct message: %w", err)
	}
	return result, nil
}
