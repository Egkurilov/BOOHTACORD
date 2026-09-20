package movepostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"voice-platform/backend/internal/channel/move_channel"
)

const topologyLockKey int64 = 441903817

const moveChannel = `
WITH state AS (
    SELECT revision FROM channel_topology_state
    WHERE singleton = TRUE AND revision = $1
), target AS (
    SELECT id FROM categories WHERE id = $3
), changed AS (
    UPDATE channels AS channel
    SET category_id = target.id,
        position = COALESCE((
            SELECT MAX(position) + 1 FROM channels
            WHERE category_id = target.id AND id <> channel.id
        ), 0),
        updated_at = now()
    FROM target, state
    WHERE channel.id = $2
    RETURNING channel.id, channel.category_id, channel.position
), revised AS (
    UPDATE channel_topology_state
    SET revision = revision + 1
    WHERE singleton = TRUE
      AND revision = $1
      AND EXISTS (SELECT 1 FROM state)
      AND EXISTS (SELECT 1 FROM changed)
    RETURNING revision
), audited AS (
    INSERT INTO audit_events (actor_user_id, event_type, metadata)
    SELECT $4, 'CHANNEL_MOVED', jsonb_build_object('channel_id', id::text, 'category_id', category_id::text)
    FROM changed CROSS JOIN revised
)
SELECT changed.id::text, changed.category_id::text, changed.position, revised.revision
FROM changed CROSS JOIN revised`

type Row interface{ Scan(...any) error }
type Transaction interface {
	Lock(context.Context, int64) error
	QueryRow(context.Context, string, ...any) Row
	Commit(context.Context) error
	Rollback(context.Context) error
}
type Database interface {
	Begin(context.Context) (Transaction, error)
}
type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }

func (repository Repository) Move(context context.Context, input movechannel.Input) (movechannel.Result, error) {
	transaction, err := repository.database.Begin(context)
	if err != nil {
		return movechannel.Result{}, fmt.Errorf("begin channel move: %w", err)
	}
	committed := false
	defer func() {
		if !committed {
			_ = transaction.Rollback(context)
		}
	}()
	if err := transaction.Lock(context, topologyLockKey); err != nil {
		return movechannel.Result{}, fmt.Errorf("lock channel topology: %w", err)
	}
	var result movechannel.Result
	err = transaction.QueryRow(context, moveChannel, input.ExpectedRevision, input.ChannelID, input.CategoryID, input.ActorID).Scan(&result.ID, &result.CategoryID, &result.Position, &result.Revision)
	if errors.Is(err, pgx.ErrNoRows) {
		return movechannel.Result{}, movechannel.ErrRevisionConflict
	}
	if err != nil {
		return movechannel.Result{}, fmt.Errorf("move channel: %w", err)
	}
	if err := transaction.Commit(context); err != nil {
		return movechannel.Result{}, fmt.Errorf("commit channel move: %w", err)
	}
	committed = true
	return result, nil
}
