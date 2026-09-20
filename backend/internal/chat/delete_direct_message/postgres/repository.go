package deletedirectmessagepostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	deletedirectmessage "voice-platform/backend/internal/chat/delete_direct_message"
)

const deleteDirectMessage = `
WITH writable_pair AS (
    SELECT dm.id FROM direct_messages dm
    WHERE dm.id = $2
      AND $3::uuid IN (dm.participant_one_id, dm.participant_two_id)
)
UPDATE direct_message_messages AS message
SET body = '', deleted_at = now(), revision = message.revision + 1
FROM writable_pair
WHERE message.id = $1
  AND message.direct_message_id = writable_pair.id
  AND message.author_id = $3
  AND message.deleted_at IS NULL
RETURNING message.id::text, message.direct_message_id::text, message.revision, message.deleted_at`

type Row interface{ Scan(...any) error }
type Database interface {
	QueryRow(context.Context, string, ...any) Row
}
type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }
func (repository Repository) Delete(context context.Context, request deletedirectmessage.Request) (deletedirectmessage.Result, error) {
	var result deletedirectmessage.Result
	err := repository.database.QueryRow(context, deleteDirectMessage, request.MessageID, request.DirectMessageID, request.ActorID).Scan(
		&result.ID, &result.DirectMessageID, &result.Revision, &result.DeletedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return deletedirectmessage.Result{}, deletedirectmessage.ErrDeleteDenied
	}
	if err != nil {
		return deletedirectmessage.Result{}, fmt.Errorf("delete direct message: %w", err)
	}
	return result, nil
}
