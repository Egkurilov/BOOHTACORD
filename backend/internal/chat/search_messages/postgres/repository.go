package searchmessagespostgres

import (
	"context"
	"fmt"

	searchmessages "voice-platform/backend/internal/chat/search_messages"
)

const searchableChannel = `SELECT EXISTS(SELECT 1 FROM channels WHERE id = $1 AND kind = 'TEXT' AND archived_at IS NULL)`
const readableDirectMessage = `SELECT EXISTS(SELECT 1 FROM direct_messages dm WHERE dm.id = $1 AND $2::uuid IN (dm.participant_one_id, dm.participant_two_id))`

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
		query, arguments := searchableChannel, []any{request.ChannelID}
		if request.ReadArchive {
			query = `SELECT EXISTS(SELECT 1 FROM channels JOIN users ON users.id=$2 WHERE channels.id=$1 AND channels.kind='TEXT' AND channels.archived_at IS NOT NULL AND channels.readonly_archive AND users.blocked_at IS NULL)`
			arguments = append(arguments, request.ActorID)
		}
		if err := repository.database.QueryRow(ctx, query, arguments...).Scan(&available); err != nil {
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
	rows, err := repository.database.Query(ctx, searchMessages, request.ActorID, nullable(request.ChannelID), nullable(request.DirectMessageID), request.Query, nullable(request.AuthorID), nullableBool(request.HasAttachment), beforeAt, beforeID, beforeKind, request.Limit+1, request.CreatedFrom, request.CreatedBefore, request.ReadArchive)
	if err != nil {
		return nil, fmt.Errorf("search messages: %w", err)
	}
	defer rows.Close()
	result := make([]searchmessages.Message, 0, request.Limit+1)
	for rows.Next() {
		var message searchmessages.Message
		if err := rows.Scan(&message.Kind, &message.ID, &message.ChannelID, &message.DirectMessageID, &message.AuthorID, &message.Body, &message.CreatedAt, &message.EditedAt, &message.Revision, &message.MessageKind); err != nil {
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

func nullableBool(value *bool) any {
	if value == nil {
		return nil
	}
	return *value
}
