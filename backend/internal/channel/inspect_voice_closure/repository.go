package inspectvoiceclosure

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Repository struct{ Database *pgxpool.Pool }

func (r Repository) Read(ctx context.Context, id string) (State, error) {
	var state State
	err := r.Database.QueryRow(ctx, `SELECT admission_closed_at IS NOT NULL,archived_at IS NOT NULL,
 (SELECT count(*) FROM voice_sfu_revocations WHERE channel_id=channels.id AND completed_at IS NULL)
 FROM channels WHERE id=$1 AND kind='VOICE'`, id).Scan(&state.Closed, &state.Archived, &state.Pending)
	if errors.Is(err, pgx.ErrNoRows) {
		return State{}, ErrNotFound
	}
	return state, err
}
