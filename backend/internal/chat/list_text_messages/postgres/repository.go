package listtextmessagespostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	listtextmessages "voice-platform/backend/internal/chat/list_text_messages"
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
	} else if request.After != "" {
		before = request.After
	}
	rows, err := repository.database.Query(context, historyQuery(request.After != ""), request.ChannelID, before, request.Limit+1, request.At != "")
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
