package edittextmessagepostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	edittextmessage "voice-platform/backend/internal/chat/edit_text_message"
)

const updateMessage = `
WITH channel AS (
    SELECT id FROM channels WHERE id = $2 AND kind = 'TEXT' AND archived_at IS NULL
), valid_mentions AS (
    SELECT account.id FROM users AS account
    WHERE account.id = ANY($6::uuid[]) AND account.blocked_at IS NULL AND account.id <> $3
    FOR SHARE OF account
)
UPDATE messages AS message
SET body = $4, mention_user_ids = $6::uuid[], edited_at = now(), revision = message.revision + 1
FROM channel
WHERE message.id = $1
  AND message.channel_id = channel.id
  AND message.author_id = $3
  AND message.deleted_at IS NULL
  AND message.revision = $5
  AND (SELECT count(*) FROM valid_mentions) = cardinality($6::uuid[])
RETURNING message.id::text, message.channel_id::text, message.author_id::text, message.client_message_id::text,
          message.body, COALESCE(message.reply_to_id::text, ''), message.revision, message.created_at, message.edited_at, message.mention_user_ids::text[]`

type Row interface{ Scan(...any) error }
type Database interface {
	QueryRow(context.Context, string, ...any) Row
}
type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }
func (repository Repository) Edit(context context.Context, request edittextmessage.Request) (edittextmessage.Result, error) {
	var result edittextmessage.Result
	mentions := append([]string{}, request.MentionUserIDs...)
	err := repository.database.QueryRow(context, updateMessage, request.MessageID, request.ChannelID, request.ActorID, request.Body, request.ExpectedRevision, mentions).Scan(
		&result.ID, &result.ChannelID, &result.AuthorID, &result.ClientMessageID, &result.Body, &result.ReplyToID, &result.Revision, &result.CreatedAt, &result.EditedAt, &result.MentionUserIDs,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return edittextmessage.Result{}, edittextmessage.ErrConflict
	}
	if err != nil {
		return edittextmessage.Result{}, fmt.Errorf("update text message: %w", err)
	}
	return result, nil
}
