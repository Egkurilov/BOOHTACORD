package auditpostgres

import (
	"context"
	"fmt"

	"voice-platform/backend/internal/identity/list_audit_events"
)

const listAuditEvents = `
SELECT event.id::text, COALESCE(event.actor_user_id::text, ''),
       COALESCE(actor.display_name, ''), COALESCE(actor.login, ''), event.event_type,
       COALESCE(event.target_user_id::text, ''), COALESCE(target.display_name, ''),
       COALESCE(target.login, ''), event.created_at
FROM audit_events event
LEFT JOIN users actor ON actor.id = event.actor_user_id
LEFT JOIN users target ON target.id = event.target_user_id
WHERE ($1::bigint = 0 OR event.id < $1)
ORDER BY event.id DESC LIMIT $2`

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
		if err := rows.Scan(&event.ID, &event.ActorID, &event.ActorDisplayName, &event.ActorLogin, &event.EventType, &event.TargetID, &event.TargetDisplayName, &event.TargetLogin, &event.CreatedAt); err != nil {
			return nil, fmt.Errorf("scan audit summary: %w", err)
		}
		events = append(events, event)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate audit summaries: %w", err)
	}
	return events, nil
}
