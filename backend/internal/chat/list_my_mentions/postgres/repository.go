package listmymentionspostgres

import (
	"context"
	"fmt"

	listmymentions "voice-platform/backend/internal/chat/list_my_mentions"
)

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

func (repository Repository) List(ctx context.Context, request listmymentions.Request) ([]listmymentions.Mention, error) {
	var beforeAt, beforeID, beforeKind any
	if request.Before != nil {
		beforeAt, beforeID, beforeKind = request.Before.CreatedAt, request.Before.ID, request.Before.Kind
	}
	rows, err := repository.database.Query(ctx, selectMentions, request.ActorID, beforeAt, beforeID, beforeKind, request.Limit+1)
	if err != nil {
		return nil, fmt.Errorf("query caller mentions: %w", err)
	}
	defer rows.Close()
	result := make([]listmymentions.Mention, 0, request.Limit+1)
	for rows.Next() {
		var item listmymentions.Mention
		if err := rows.Scan(&item.Kind, &item.ID, &item.ConversationID, &item.AuthorID, &item.CreatedAt); err != nil {
			return nil, fmt.Errorf("scan caller mention: %w", err)
		}
		result = append(result, item)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate caller mentions: %w", err)
	}
	return result, nil
}
