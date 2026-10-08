package archivereadonlytextpostgres

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	action "voice-platform/backend/internal/channel/archive_readonly_text"
)

type Repository struct{ pool *pgxpool.Pool }

func New(pool *pgxpool.Pool) Repository { return Repository{pool} }
func (r Repository) Archive(ctx context.Context, in action.Input) (action.Result, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return action.Result{}, err
	}
	defer tx.Rollback(context.Background())
	if _, err = tx.Exec(ctx, "SELECT pg_advisory_xact_lock($1)", int64(441903817)); err != nil {
		return action.Result{}, err
	}
	var result action.Result
	err = tx.QueryRow(ctx, changeChannel, in.ExpectedRevision, in.ChannelID, in.ActorID).Scan(&result.ID, &result.Revision)
	if errors.Is(err, pgx.ErrNoRows) {
		return action.Result{}, action.ErrConflict
	}
	if err != nil {
		return action.Result{}, err
	}
	if err = tx.Commit(ctx); err != nil {
		return action.Result{}, err
	}
	return result, nil
}
