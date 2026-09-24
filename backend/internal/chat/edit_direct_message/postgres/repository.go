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
    SELECT dm.id, CASE WHEN dm.participant_one_id = $3::uuid THEN dm.participant_two_id ELSE dm.participant_one_id END AS other_id FROM direct_messages dm
    WHERE dm.id = $2
      AND $3::uuid IN (dm.participant_one_id, dm.participant_two_id)
), valid_mentions AS (
    SELECT target.id FROM writable_pair
    JOIN users target ON target.id = writable_pair.other_id
    WHERE target.id = ANY($6::uuid[]) AND target.blocked_at IS NULL
    FOR SHARE OF target
)
UPDATE direct_message_messages AS message
SET body = $4, mention_user_ids = $6::uuid[], edited_at = now(), revision = message.revision + 1
FROM writable_pair
WHERE message.id = $1
  AND message.direct_message_id = writable_pair.id
  AND message.author_id = $3
  AND message.deleted_at IS NULL
  AND message.revision = $5
  AND (SELECT count(*) FROM valid_mentions) = cardinality($6::uuid[])
RETURNING message.id::text, message.direct_message_id::text, message.author_id::text, message.client_message_id::text,
          message.body, COALESCE(message.reply_to_id::text, ''), message.revision, message.created_at, message.edited_at, message.mention_user_ids::text[]`

type Row interface{ Scan(...any) error }
type Database interface {
	QueryRow(context.Context, string, ...any) Row
}
type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }
func (repository Repository) Edit(context context.Context, request editdirectmessage.Request) (editdirectmessage.Result, error) {
	var result editdirectmessage.Result
	mentions := append([]string{}, request.MentionUserIDs...)
	err := repository.database.QueryRow(context, updateDirectMessage, request.MessageID, request.DirectMessageID, request.ActorID, request.Body, request.ExpectedRevision, mentions).Scan(
		&result.ID, &result.DirectMessageID, &result.AuthorID, &result.ClientMessageID, &result.Body, &result.ReplyToID, &result.Revision, &result.CreatedAt, &result.EditedAt, &result.MentionUserIDs,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return editdirectmessage.Result{}, editdirectmessage.ErrConflict
	}
	if err != nil {
		return editdirectmessage.Result{}, fmt.Errorf("update direct message: %w", err)
	}
	return result, nil
}
