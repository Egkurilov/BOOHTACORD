package listtextmessagespostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	listtextmessages "voice-platform/backend/internal/chat/list_text_messages"
)

const selectChannel = `SELECT EXISTS(SELECT 1 FROM channels WHERE id = $1 AND kind = 'TEXT' AND archived_at IS NULL)`
const selectMessages = `
WITH cursor AS (
    SELECT created_at, id FROM messages WHERE id = $2 AND channel_id = $1
)
SELECT messages.id::text, messages.channel_id::text, messages.author_id::text, messages.client_message_id::text,
       CASE WHEN messages.deleted_at IS NULL THEN messages.body ELSE '' END, COALESCE(messages.reply_to_id::text, ''), messages.created_at, messages.edited_at, messages.revision, messages.deleted_at IS NOT NULL,
       CASE WHEN messages.deleted_at IS NULL THEN messages.mention_user_ids::text[] ELSE ARRAY[]::text[] END,
       COALESCE(
           jsonb_agg(
               jsonb_build_object('id', attachments.id::text, 'original_name', attachments.original_name, 'byte_size', attachments.byte_size)
               ORDER BY message_attachments.position
           ) FILTER (WHERE attachments.id IS NOT NULL AND messages.deleted_at IS NULL),
           '[]'::jsonb
       )::text, messages.kind
FROM messages
LEFT JOIN message_attachments ON message_attachments.message_id = messages.id
LEFT JOIN attachments ON attachments.id = message_attachments.attachment_id AND attachments.state = 'ATTACHED'
WHERE messages.channel_id = $1
  AND ($2::uuid IS NULL OR (messages.created_at, messages.id) < (SELECT created_at, id FROM cursor)
       OR ($4::bool AND messages.id = $2::uuid))
GROUP BY messages.id, messages.channel_id, messages.author_id, messages.client_message_id, messages.body, messages.reply_to_id, messages.created_at, messages.edited_at, messages.revision, messages.deleted_at
ORDER BY messages.created_at DESC, messages.id DESC
LIMIT $3`

type Row interface{ Scan(...any) error }
type Rows interface {
	Next() bool
	Scan(...any) error
	Close()
	Err() error
}
type Database interface {
	QueryRow(context.Context, string, ...any) Row
	Query(context.Context, string, ...any) (Rows, error)
}
type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }
func (repository Repository) List(context context.Context, request listtextmessages.Request) ([]listtextmessages.Message, error) {
	var available bool
	if err := repository.database.QueryRow(context, selectChannel, request.ChannelID).Scan(&available); err != nil {
		return nil, fmt.Errorf("select text channel: %w", err)
	}
	if !available {
		return nil, listtextmessages.ErrChannelUnavailable
	}
	var before any
	if request.Before != "" {
		before = request.Before
	} else if request.At != "" {
		before = request.At
	}
	rows, err := repository.database.Query(context, selectMessages, request.ChannelID, before, request.Limit+1, request.At != "")
	if err != nil {
		return nil, fmt.Errorf("select text messages: %w", err)
	}
	defer rows.Close()
	result := make([]listtextmessages.Message, 0, request.Limit+1)
	for rows.Next() {
		var message listtextmessages.Message
		var attachments []byte
		if err := rows.Scan(&message.ID, &message.ChannelID, &message.AuthorID, &message.ClientMessageID, &message.Body, &message.ReplyToID, &message.CreatedAt, &message.EditedAt, &message.Revision, &message.Deleted, &message.MentionUserIDs, &attachments, &message.Kind); err != nil {
			return nil, fmt.Errorf("scan text message: %w", err)
		}
		decoded, err := decodeAttachments(attachments)
		if err != nil {
			return nil, fmt.Errorf("decode text message attachments: %w", err)
		}
		message.Attachments = decoded
		result = append(result, message)
	}
	if err := rows.Err(); err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return nil, fmt.Errorf("iterate text messages: %w", err)
	}
	return result, nil
}
