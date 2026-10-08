package changetextpinpostgres

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	action "voice-platform/backend/internal/chat/change_text_pin"
)

type Repository struct{ pool *pgxpool.Pool }

func New(pool *pgxpool.Pool) Repository { return Repository{pool} }
func (r Repository) Set(ctx context.Context, in action.Input) (action.Result, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return action.Result{}, err
	}
	defer tx.Rollback(context.Background())
	var active bool
	err = tx.QueryRow(ctx, `SELECT true FROM users WHERE id=$1 AND blocked_at IS NULL AND role='ADMINISTRATOR' FOR SHARE`, in.ActorID).Scan(&active)
	if errors.Is(err, pgx.ErrNoRows) {
		return action.Result{}, action.ErrUnavailable
	}
	if err != nil {
		return action.Result{}, err
	}
	err = tx.QueryRow(ctx, `SELECT true FROM messages m JOIN channels c ON c.id=m.channel_id
 WHERE m.id=$1 AND c.id=$2 AND c.kind='TEXT' AND c.archived_at IS NULL AND m.deleted_at IS NULL
 FOR UPDATE OF m FOR SHARE OF c`, in.MessageID, in.ChannelID).Scan(&active)
	if errors.Is(err, pgx.ErrNoRows) {
		return action.Result{}, action.ErrUnavailable
	}
	if err != nil {
		return action.Result{}, err
	}
	query := "DELETE FROM text_message_pins WHERE message_id=$1"
	args := []any{in.MessageID}
	if in.Present {
		query = "INSERT INTO text_message_pins(message_id,pinned_by) VALUES($1,$2) ON CONFLICT DO NOTHING"
		args = append(args, in.ActorID)
	}
	changed, err := tx.Exec(ctx, query, args...)
	if err != nil {
		return action.Result{}, err
	}
	if changed.RowsAffected() != 0 {
		_, err = tx.Exec(ctx, `INSERT INTO audit_events(actor_user_id,event_type,metadata) VALUES($1,'TEXT_MESSAGE_PIN_CHANGED',jsonb_build_object('channel_id',$2::text,'message_id',$3::text,'present',$4::boolean))`, in.ActorID, in.ChannelID, in.MessageID, in.Present)
		if err != nil {
			return action.Result{}, err
		}
	}
	if err = tx.Commit(ctx); err != nil {
		return action.Result{}, err
	}
	return action.Result{Changed: changed.RowsAffected() != 0}, nil
}
