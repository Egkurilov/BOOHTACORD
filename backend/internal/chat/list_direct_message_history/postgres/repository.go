package listdirectmessagehistorypostgres

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	listdirectmessagehistory "voice-platform/backend/internal/chat/list_direct_message_history"
)

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
	} else if request.At != "" {
		before = request.At
	} else if request.After != "" {
		before = request.After
	}
	rows, err := repository.database.Query(context, historyQuery(request.After != ""), request.DirectMessageID, request.ActorID, before, request.Limit+1, request.At != "")
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
