package searchmessagespostgres

import (
	"context"
	"fmt"

	searchmessages "voice-platform/backend/internal/chat/search_messages"
)

const searchableChannel = `SELECT EXISTS(SELECT 1 FROM channels WHERE id = $1 AND kind = 'TEXT' AND archived_at IS NULL)`
const readableDirectMessage = `SELECT EXISTS(SELECT 1 FROM direct_messages dm WHERE dm.id = $1 AND $2::uuid IN (dm.participant_one_id, dm.participant_two_id))`

const searchMessages = `
WITH matching AS (
    SELECT 'CHANNEL'::text AS kind, m.id, m.channel_id, NULL::uuid AS direct_message_id,
           m.author_id, m.body, m.created_at, m.edited_at, m.revision
    FROM messages m JOIN channels channel ON channel.id = m.channel_id
    WHERE channel.kind = 'TEXT' AND channel.archived_at IS NULL AND m.deleted_at IS NULL
      AND ($2::uuid IS NULL OR m.channel_id = $2::uuid) AND $3::uuid IS NULL
      AND m.search_vector @@ websearch_to_tsquery('simple', $4)
    UNION ALL
    SELECT 'DIRECT_MESSAGE'::text AS kind, dm_message.id, NULL::uuid AS channel_id, dm_message.direct_message_id,
           dm_message.author_id, dm_message.body, dm_message.created_at, dm_message.edited_at, dm_message.revision
    FROM direct_message_messages dm_message JOIN direct_messages dm ON dm.id = dm_message.direct_message_id
    WHERE dm_message.deleted_at IS NULL AND $2::uuid IS NULL
      AND ($3::uuid IS NULL OR dm.id = $3::uuid)
      AND $1::uuid IN (dm.participant_one_id, dm.participant_two_id)
      AND dm_message.search_vector @@ websearch_to_tsquery('simple', $4)
)
SELECT kind, id::text, COALESCE(channel_id::text, ''), COALESCE(direct_message_id::text, ''),
       author_id::text, body, created_at, edited_at, revision
FROM matching
WHERE $5::timestamptz IS NULL OR (created_at, id, kind) < ($5::timestamptz, $6::uuid, $7::text)
ORDER BY created_at DESC, id DESC, kind DESC
LIMIT $8`

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

func (repository Repository) Search(ctx context.Context, request searchmessages.Request) ([]searchmessages.Message, error) {
	if request.ChannelID != "" {
		var available bool
		if err := repository.database.QueryRow(ctx, searchableChannel, request.ChannelID).Scan(&available); err != nil {
			return nil, fmt.Errorf("select searchable channel: %w", err)
		}
		if !available {
			return nil, searchmessages.ErrConversationUnavailable
		}
	} else if request.DirectMessageID != "" {
		var available bool
		if err := repository.database.QueryRow(ctx, readableDirectMessage, request.DirectMessageID, request.ActorID).Scan(&available); err != nil {
			return nil, fmt.Errorf("select readable direct message: %w", err)
		}
		if !available {
			return nil, searchmessages.ErrConversationUnavailable
		}
	}
	var beforeAt, beforeID, beforeKind any
	if request.Before != nil {
		beforeAt, beforeID, beforeKind = request.Before.CreatedAt, request.Before.ID, request.Before.Kind
	}
	rows, err := repository.database.Query(ctx, searchMessages, request.ActorID, nullable(request.ChannelID), nullable(request.DirectMessageID), request.Query, beforeAt, beforeID, beforeKind, request.Limit+1)
	if err != nil {
		return nil, fmt.Errorf("search messages: %w", err)
	}
	defer rows.Close()
	result := make([]searchmessages.Message, 0, request.Limit+1)
	for rows.Next() {
		var message searchmessages.Message
		if err := rows.Scan(&message.Kind, &message.ID, &message.ChannelID, &message.DirectMessageID, &message.AuthorID, &message.Body, &message.CreatedAt, &message.EditedAt, &message.Revision); err != nil {
			return nil, fmt.Errorf("scan message search result: %w", err)
		}
		result = append(result, message)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate message search results: %w", err)
	}
	return result, nil
}

func nullable(value string) any {
	if value == "" {
		return nil
	}
	return value
}
