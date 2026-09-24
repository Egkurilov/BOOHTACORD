package listdirectmessagehistorypostgres

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	listdirectmessagehistory "voice-platform/backend/internal/chat/list_direct_message_history"
)

const selectReadableDirectMessage = `
SELECT EXISTS(
    SELECT 1 FROM direct_messages dm
    WHERE dm.id = $1
      AND $2::uuid IN (dm.participant_one_id, dm.participant_two_id)
)`

const selectDirectMessageHistory = `
WITH readable_pair AS (
    SELECT dm.id FROM direct_messages dm
    WHERE dm.id = $1
      AND $2::uuid IN (dm.participant_one_id, dm.participant_two_id)
), cursor AS (
    SELECT created_at, id FROM direct_message_messages
    WHERE id = $3::uuid AND direct_message_id = (SELECT id FROM readable_pair)
)
SELECT m.id::text, m.direct_message_id::text, m.author_id::text, m.client_message_id::text,
       CASE WHEN m.deleted_at IS NULL THEN m.body ELSE '' END, COALESCE(m.reply_to_id::text, ''), m.created_at, m.edited_at, m.revision, m.deleted_at IS NOT NULL,
       CASE WHEN m.deleted_at IS NULL THEN m.mention_user_ids::text[] ELSE ARRAY[]::text[] END,
       COALESCE(reply.id::text, ''), COALESCE(reply.author_id::text, ''), CASE WHEN reply.deleted_at IS NULL THEN COALESCE(reply.body, '') ELSE '' END, reply.deleted_at IS NOT NULL,
       COALESCE((
           SELECT jsonb_agg(jsonb_build_object('id', a.id::text, 'original_name', a.original_name, 'byte_size', a.byte_size) ORDER BY link.position)
           FROM direct_message_attachments link
           JOIN attachments a ON a.id = link.attachment_id
           WHERE link.message_id = m.id AND a.state = 'ATTACHED' AND m.deleted_at IS NULL
       ), '[]'::jsonb)
FROM direct_message_messages m
LEFT JOIN direct_message_messages reply
  ON reply.id = m.reply_to_id
 AND reply.direct_message_id = m.direct_message_id
WHERE m.direct_message_id = (SELECT id FROM readable_pair)
  AND ($3::uuid IS NULL OR (m.created_at, m.id) < (SELECT created_at, id FROM cursor))
ORDER BY m.created_at DESC, m.id DESC
LIMIT $4`

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
func (repository Repository) List(context context.Context, request listdirectmessagehistory.Request) ([]listdirectmessagehistory.Message, error) {
	var available bool
	if err := repository.database.QueryRow(context, selectReadableDirectMessage, request.DirectMessageID, request.ActorID).Scan(&available); err != nil {
		return nil, fmt.Errorf("select readable direct message: %w", err)
	}
	if !available {
		return nil, listdirectmessagehistory.ErrDirectMessageUnavailable
	}
	var before any
	if request.Before != "" {
		before = request.Before
	}
	rows, err := repository.database.Query(context, selectDirectMessageHistory, request.DirectMessageID, request.ActorID, before, request.Limit+1)
	if err != nil {
		return nil, fmt.Errorf("select direct message history: %w", err)
	}
	defer rows.Close()
	result := make([]listdirectmessagehistory.Message, 0, request.Limit+1)
	for rows.Next() {
		var message listdirectmessagehistory.Message
		var preview listdirectmessagehistory.ReplyPreview
		var attachments []byte
		if err := rows.Scan(&message.ID, &message.DirectMessageID, &message.AuthorID, &message.ClientMessageID, &message.Body, &message.ReplyToID, &message.CreatedAt, &message.EditedAt, &message.Revision, &message.Deleted, &message.MentionUserIDs, &preview.ID, &preview.AuthorID, &preview.Body, &preview.Deleted, &attachments); err != nil {
			return nil, fmt.Errorf("scan direct message history: %w", err)
		}
		if err := json.Unmarshal(attachments, &message.Attachments); err != nil {
			return nil, fmt.Errorf("decode direct message attachment metadata: %w", err)
		}
		if preview.ID != "" {
			message.ReplyPreview = &preview
		}
		result = append(result, message)
	}
	if err := rows.Err(); err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return nil, fmt.Errorf("iterate direct message history: %w", err)
	}
	return result, nil
}
