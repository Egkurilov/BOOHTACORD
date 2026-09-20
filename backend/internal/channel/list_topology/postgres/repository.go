package listtopologypostgres

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgtype"
	listtopology "voice-platform/backend/internal/channel/list_topology"
)

const selectRevision = `SELECT COALESCE((SELECT revision FROM channel_topology_state WHERE singleton = TRUE), 0)`
const selectTopology = `
SELECT category.id::text, category.name, category.position,
       channel.id::text, channel.name, channel.kind, channel.position, channel.admission_closed_at IS NOT NULL
FROM categories AS category
LEFT JOIN channels AS channel ON channel.category_id = category.id AND channel.archived_at IS NULL
ORDER BY category.position, channel.position`

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
func (repository Repository) List(context context.Context) (listtopology.Result, error) {
	var result listtopology.Result
	if err := repository.database.QueryRow(context, selectRevision).Scan(&result.Revision); err != nil {
		return result, fmt.Errorf("select topology revision: %w", err)
	}
	rows, err := repository.database.Query(context, selectTopology)
	if err != nil {
		return result, fmt.Errorf("select channel topology: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var category listtopology.Category
		var channelID, channelName, channelKind pgtype.Text
		var channelPosition pgtype.Int4
		var admissionClosed pgtype.Bool
		if err := rows.Scan(&category.ID, &category.Name, &category.Position, &channelID, &channelName, &channelKind, &channelPosition, &admissionClosed); err != nil {
			return result, fmt.Errorf("scan channel topology: %w", err)
		}
		if len(result.Categories) == 0 || result.Categories[len(result.Categories)-1].ID != category.ID {
			result.Categories = append(result.Categories, category)
		}
		if channelID.Valid {
			last := &result.Categories[len(result.Categories)-1]
			last.Channels = append(last.Channels, listtopology.Channel{ID: channelID.String, Name: channelName.String, Kind: channelKind.String, Position: int(channelPosition.Int32), AdmissionClosed: admissionClosed.Bool})
		}
	}
	if err := rows.Err(); err != nil {
		return result, fmt.Errorf("iterate channel topology: %w", err)
	}
	return result, nil
}
