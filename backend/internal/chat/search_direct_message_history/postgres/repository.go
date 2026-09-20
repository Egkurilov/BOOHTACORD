package searchdirectmessagehistorypostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	searchdirectmessagehistory "voice-platform/backend/internal/chat/search_direct_message_history"
)

const selectReadableDirectMessage = `
SELECT EXISTS(
    SELECT 1 FROM direct_messages dm
    WHERE dm.id = $1
      AND $2::uuid IN (dm.participant_one_id, dm.participant_two_id)
)`

const searchDirectMessageHistory = `
WITH readable_pair AS (
    SELECT dm.id FROM direct_messages dm
    WHERE dm.id = $1
      AND $2::uuid IN (dm.participant_one_id, dm.participant_two_id)
), cursor AS (
    SELECT created_at, id FROM direct_message_messages
    WHERE id = $3::uuid AND direct_message_id = (SELECT id FROM readable_pair)
)
SELECT m.id::text, m.direct_message_id::text, m.author_id::text, m.body, m.created_at, m.edited_at, m.revision
FROM direct_message_messages m
WHERE m.direct_message_id = (SELECT id FROM readable_pair)
  AND m.deleted_at IS NULL
  AND m.search_vector @@ websearch_to_tsquery('simple', $4)
  AND ($3::uuid IS NULL OR (m.created_at, m.id) < (SELECT created_at, id FROM cursor))
ORDER BY m.created_at DESC, m.id DESC
LIMIT $5`

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
func (repository Repository) Search(context context.Context, request searchdirectmessagehistory.Request) ([]searchdirectmessagehistory.Message, error) {
	var available bool
	if err := repository.database.QueryRow(context, selectReadableDirectMessage, request.DirectMessageID, request.ActorID).Scan(&available); err != nil {
		return nil, fmt.Errorf("select readable direct message: %w", err)
	}
	if !available {
		return nil, searchdirectmessagehistory.ErrDirectMessageUnavailable
	}
	var before any
	if request.Before != "" {
		before = request.Before
	}
	rows, err := repository.database.Query(context, searchDirectMessageHistory, request.DirectMessageID, request.ActorID, before, request.Query, request.Limit+1)
	if err != nil {
		return nil, fmt.Errorf("search direct message history: %w", err)
	}
	defer rows.Close()
	result := make([]searchdirectmessagehistory.Message, 0, request.Limit+1)
	for rows.Next() {
		var message searchdirectmessagehistory.Message
		if err := rows.Scan(&message.ID, &message.DirectMessageID, &message.AuthorID, &message.Body, &message.CreatedAt, &message.EditedAt, &message.Revision); err != nil {
			return nil, fmt.Errorf("scan direct message search result: %w", err)
		}
		result = append(result, message)
	}
	if err := rows.Err(); err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return nil, fmt.Errorf("iterate direct message search results: %w", err)
	}
	return result, nil
}
