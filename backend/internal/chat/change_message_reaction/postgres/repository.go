package changemessagereactionpostgres

import (
	"context"
	"github.com/jackc/pgx/v5/pgxpool"
	action "voice-platform/backend/internal/chat/change_message_reaction"
)

type Repository struct{ pool *pgxpool.Pool }

func New(pool *pgxpool.Pool) Repository { return Repository{pool} }
func (r Repository) Set(ctx context.Context, in action.Input) (action.Result, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return action.Result{}, err
	}
	defer tx.Rollback(context.Background())
	recipients, err := lockTarget(ctx, tx, in)
	if err != nil {
		return action.Result{}, err
	}
	table := "text_message_reactions"
	if in.Direct {
		table = "direct_message_reactions"
	}
	statement := "DELETE FROM " + table + " WHERE message_id=$1 AND account_id=$2 AND emoji=$3"
	if in.Present {
		statement = "INSERT INTO " + table + "(message_id,account_id,emoji) VALUES($1,$2,$3) ON CONFLICT DO NOTHING"
	}
	changed, err := tx.Exec(ctx, statement, in.MessageID, in.ActorID, in.Emoji)
	if err != nil {
		return action.Result{}, err
	}
	if err = tx.Commit(ctx); err != nil {
		return action.Result{}, err
	}
	return action.Result{Changed: changed.RowsAffected() != 0, Recipients: recipients}, nil
}
