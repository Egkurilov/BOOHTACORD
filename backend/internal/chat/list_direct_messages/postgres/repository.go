package listdirectmessagespostgres

import (
	"context"
	"fmt"

	listdirectmessages "voice-platform/backend/internal/chat/list_direct_messages"
)

const selectDirectMessages = `
WITH pair AS (
    SELECT dm.id, dm.participant_two_id AS other_participant_id, dm.created_at
    FROM direct_messages dm
    WHERE dm.participant_one_id = $1::uuid
    UNION ALL
    SELECT dm.id, dm.participant_one_id AS other_participant_id, dm.created_at
    FROM direct_messages dm
    WHERE dm.participant_two_id = $1::uuid
)
SELECT pair.id::text, pair.other_participant_id::text, account.display_name, pair.created_at,
       COUNT(message.id) FILTER (
           WHERE message.author_id <> $1::uuid
             AND (cursor.message_id IS NULL OR (message.created_at, message.id) > (cursor.message_created_at, cursor.message_id))
             AND message.deleted_at IS NULL
       ) AS unread_count,
       COUNT(message.id) FILTER (
           WHERE message.author_id <> $1::uuid
             AND message.deleted_at IS NULL
             AND $1::uuid = ANY(message.mention_user_ids)
             AND (cursor.message_id IS NULL OR (message.created_at, message.id) > (cursor.message_created_at, cursor.message_id))
       ) AS mention_count
FROM pair
JOIN users account ON account.id = pair.other_participant_id
LEFT JOIN direct_message_read_cursors cursor
  ON cursor.account_id = $1::uuid
 AND cursor.direct_message_id = pair.id
LEFT JOIN direct_message_messages message
  ON message.direct_message_id = pair.id
GROUP BY pair.id, pair.other_participant_id, account.display_name, pair.created_at
ORDER BY pair.created_at DESC, pair.id DESC`

type Rows interface {
	Next() bool
	Scan(...any) error
	Close()
	Err() error
}
type Database interface {
	Query(context.Context, string, ...any) (Rows, error)
}
type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }
func (repository Repository) List(context context.Context, request listdirectmessages.Request) ([]listdirectmessages.DirectMessage, error) {
	rows, err := repository.database.Query(context, selectDirectMessages, request.ActorID)
	if err != nil {
		return nil, fmt.Errorf("select direct messages: %w", err)
	}
	defer rows.Close()
	result := make([]listdirectmessages.DirectMessage, 0)
	for rows.Next() {
		var directMessage listdirectmessages.DirectMessage
		if err := rows.Scan(&directMessage.ID, &directMessage.OtherParticipantID, &directMessage.OtherParticipantDisplayName, &directMessage.CreatedAt, &directMessage.UnreadCount, &directMessage.MentionCount); err != nil {
			return nil, fmt.Errorf("scan direct message: %w", err)
		}
		result = append(result, directMessage)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate direct messages: %w", err)
	}
	return result, nil
}
