package searchtextmessagespostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	searchtextmessages "voice-platform/backend/internal/chat/search_text_messages"
)

const selectTextChannel = `SELECT EXISTS(SELECT 1 FROM channels WHERE id = $1 AND kind = 'TEXT' AND archived_at IS NULL)`

const searchTextMessages = `
WITH current_channel AS (
    SELECT id FROM channels
    WHERE id = $1
      AND kind = 'TEXT'
      AND archived_at IS NULL
), cursor AS (
    SELECT created_at, id FROM messages
    WHERE id = $2::uuid
      AND channel_id = (SELECT id FROM current_channel)
)
SELECT m.id::text, m.channel_id::text, m.author_id::text, m.body, m.created_at, m.edited_at, m.revision, m.kind
FROM messages m
WHERE m.channel_id = (SELECT id FROM current_channel)
  AND m.deleted_at IS NULL
  AND m.search_vector @@ websearch_to_tsquery('simple', $3)
  AND ($2::uuid IS NULL OR (m.created_at, m.id) < (SELECT created_at, id FROM cursor))
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

func (repository Repository) Search(context context.Context, request searchtextmessages.Request) ([]searchtextmessages.Message, error) {
	var available bool
	if err := repository.database.QueryRow(context, selectTextChannel, request.ChannelID).Scan(&available); err != nil {
		return nil, fmt.Errorf("select text channel: %w", err)
	}
	if !available {
		return nil, searchtextmessages.ErrChannelUnavailable
	}
	var before any
	if request.Before != "" {
		before = request.Before
	}
	rows, err := repository.database.Query(context, searchTextMessages, request.ChannelID, before, request.Query, request.Limit+1)
	if err != nil {
		return nil, fmt.Errorf("search text messages: %w", err)
	}
	defer rows.Close()
	result := make([]searchtextmessages.Message, 0, request.Limit+1)
	for rows.Next() {
		var message searchtextmessages.Message
		if err := rows.Scan(&message.ID, &message.ChannelID, &message.AuthorID, &message.Body, &message.CreatedAt, &message.EditedAt, &message.Revision, &message.Kind); err != nil {
			return nil, fmt.Errorf("scan text message search result: %w", err)
		}
		result = append(result, message)
	}
	if err := rows.Err(); err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return nil, fmt.Errorf("iterate text message search results: %w", err)
	}
	return result, nil
}
