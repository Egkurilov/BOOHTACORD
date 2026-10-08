package listarchivedtextpostgres

import (
	"context"
	"github.com/jackc/pgx/v5/pgxpool"
	list "voice-platform/backend/internal/channel/list_archived_text"
)

type Repository struct{ pool *pgxpool.Pool }

func New(pool *pgxpool.Pool) Repository { return Repository{pool} }
func (r Repository) List(ctx context.Context, in list.Input) (list.Result, error) {
	result := list.Result{Channels: []list.Channel{}}
	if err := r.pool.QueryRow(ctx, "SELECT revision FROM channel_topology_state WHERE singleton=TRUE").Scan(&result.Revision); err != nil {
		return result, err
	}
	var cursor any
	if in.Cursor != "" {
		cursor = in.Cursor
	}
	rows, err := r.pool.Query(ctx, `SELECT channel.id::text,channel.name,channel.description,category.name,channel.archived_at
 FROM users JOIN channels channel ON channel.kind='TEXT' AND channel.readonly_archive AND channel.archived_at IS NOT NULL
 JOIN categories category ON category.id=channel.category_id
 WHERE users.id=$1 AND users.blocked_at IS NULL AND ($2::uuid IS NULL OR channel.id>$2::uuid)
 ORDER BY channel.id LIMIT $3`, in.ActorID, cursor, in.Limit+1)
	if err != nil {
		return result, err
	}
	defer rows.Close()
	for rows.Next() {
		var channel list.Channel
		if err = rows.Scan(&channel.ID, &channel.Name, &channel.Description, &channel.CategoryName, &channel.ArchivedAt); err != nil {
			return result, err
		}
		result.Channels = append(result.Channels, channel)
	}
	return result, rows.Err()
}
