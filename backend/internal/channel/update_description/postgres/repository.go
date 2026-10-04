package descriptionpostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"voice-platform/backend/internal/channel/update_description"
)

const topologyLockKey int64 = 441903817

const updateDescription = `
WITH state AS (
    SELECT revision FROM channel_topology_state
    WHERE singleton = TRUE AND revision = $1
), changed AS (
    UPDATE channels
    SET description = $3, updated_at = now()
    WHERE id = $2 AND archived_at IS NULL
      AND EXISTS (SELECT 1 FROM state)
    RETURNING id, description
), revised AS (
    UPDATE channel_topology_state
    SET revision = revision + 1
    WHERE singleton = TRUE AND revision = $1
      AND EXISTS (SELECT 1 FROM changed)
    RETURNING revision
), audited AS (
    INSERT INTO audit_events (actor_user_id, event_type, metadata)
    SELECT $4, 'CHANNEL_DESCRIPTION_UPDATED', jsonb_build_object('channel_id', id::text)
    FROM changed CROSS JOIN revised
)
SELECT changed.id::text, changed.description, revised.revision
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

func (repository Repository) Update(ctx context.Context, input updatedescription.Input) (updatedescription.Result, error) {
	tx, err := repository.database.Begin(ctx)
	if err != nil {
		return updatedescription.Result{}, fmt.Errorf("begin channel description update: %w", err)
	}
	committed := false
	defer func() {
		if !committed {
			_ = tx.Rollback(ctx)
		}
	}()
	if err := tx.Lock(ctx, topologyLockKey); err != nil {
		return updatedescription.Result{}, fmt.Errorf("lock channel topology: %w", err)
	}
	var result updatedescription.Result
	err = tx.QueryRow(ctx, updateDescription, input.ExpectedRevision, input.ChannelID, input.Description, input.ActorID).Scan(&result.ID, &result.Description, &result.Revision)
	if errors.Is(err, pgx.ErrNoRows) {
		return updatedescription.Result{}, updatedescription.ErrRevisionConflict
	}
	if err != nil {
		return updatedescription.Result{}, fmt.Errorf("update channel description: %w", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return updatedescription.Result{}, fmt.Errorf("commit channel description update: %w", err)
	}
	committed = true
	return result, nil
}
