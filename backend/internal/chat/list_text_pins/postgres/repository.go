package listtextpinspostgres

import (
	"context"
	"github.com/jackc/pgx/v5/pgxpool"
	list "voice-platform/backend/internal/chat/list_text_pins"
)

type Repository struct{ pool *pgxpool.Pool }

func New(pool *pgxpool.Pool) Repository { return Repository{pool} }
func (r Repository) List(ctx context.Context, in list.Request) ([]list.Pin, error) {
	var available bool
	err := r.pool.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM users u JOIN channels c ON c.id=$2 WHERE u.id=$1 AND u.blocked_at IS NULL AND c.kind='TEXT' AND c.archived_at IS NULL)`, in.ActorID, in.ChannelID).Scan(&available)
	if err != nil {
		return nil, err
	}
	if !available {
		return nil, list.ErrUnavailable
	}
	var at, id any
	if in.Cursor != nil {
		at = in.Cursor.PinnedAt
		id = in.Cursor.MessageID
	}
	rows, err := r.pool.Query(ctx, `SELECT m.id::text,p.pinned_at,m.author_id::text,left(m.body,240),m.created_at FROM text_message_pins p JOIN messages m ON m.id=p.message_id
 JOIN channels c ON c.id=m.channel_id JOIN users u ON u.id=$1 AND u.blocked_at IS NULL
 WHERE c.id=$2 AND c.kind='TEXT' AND c.archived_at IS NULL AND m.deleted_at IS NULL
 AND ($3::timestamptz IS NULL OR (p.pinned_at,p.message_id)<($3::timestamptz,$4::uuid))
 ORDER BY p.pinned_at DESC,p.message_id DESC LIMIT $5`, in.ActorID, in.ChannelID, at, id, in.Limit+1)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	result := []list.Pin{}
	for rows.Next() {
		var pin list.Pin
		if err = rows.Scan(&pin.MessageID, &pin.PinnedAt, &pin.AuthorID, &pin.Preview, &pin.MessageCreatedAt); err != nil {
			return nil, err
		}
		result = append(result, pin)
	}
	return result, rows.Err()
}
