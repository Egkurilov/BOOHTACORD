package auditpostgres

import (
	"context"
	"fmt"

	"voice-platform/backend/internal/identity/list_audit_events"
)

const listAuditEvents = `
SELECT id::text, COALESCE(actor_user_id::text, ''), event_type,
       COALESCE(target_user_id::text, ''), created_at
FROM audit_events
WHERE ($1::bigint = 0 OR id < $1)
ORDER BY id DESC LIMIT $2`

type Rows interface {
	Next() bool
	Scan(...any) error
	Err() error
	Close()
}
type Database interface {
	Query(context.Context, string, ...any) (Rows, error)
}
type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }

func (repository Repository) List(ctx context.Context, beforeID int64, limit int) ([]listauditevents.Event, error) {
	rows, err := repository.database.Query(ctx, listAuditEvents, beforeID, limit)
	if err != nil {
		return nil, fmt.Errorf("query audit summaries: %w", err)
	}
	defer rows.Close()
	var events []listauditevents.Event
	for rows.Next() {
		var event listauditevents.Event
		if err := rows.Scan(&event.ID, &event.ActorID, &event.EventType, &event.TargetID, &event.CreatedAt); err != nil {
			return nil, fmt.Errorf("scan audit summary: %w", err)
		}
		events = append(events, event)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate audit summaries: %w", err)
	}
	return events, nil
}
