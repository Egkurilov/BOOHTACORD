package reorderpostgres

import (
	"context"
	"errors"
	"fmt"
	"github.com/jackc/pgx/v5"
	"voice-platform/backend/internal/channel/reorder_channels"
)

const topologyLockKey int64 = 441903817

const reorderChannels = `
WITH state AS (
    SELECT revision FROM channel_topology_state
    WHERE singleton = TRUE AND revision = $1
), category AS (
    SELECT id FROM categories WHERE id = $2
), requested AS (
    SELECT id::uuid AS id, (ordinality - 1)::integer AS position
    FROM unnest($3::text[]) WITH ORDINALITY AS requested_ids(id, ordinality)
), valid AS (
    SELECT (SELECT COUNT(*) FROM requested) = (SELECT COUNT(*) FROM channels WHERE category_id = $2) AS complete
), changed AS (
    UPDATE channels AS channel
    SET position = requested.position, updated_at = now()
    FROM requested, state, category, valid
    WHERE channel.id = requested.id
      AND channel.category_id = category.id
      AND valid.complete
    RETURNING channel.id
), revised AS (
    UPDATE channel_topology_state
    SET revision = revision + 1
    WHERE singleton = TRUE
      AND revision = $1
      AND EXISTS (SELECT 1 FROM state)
	  AND EXISTS (SELECT 1 FROM category)
      AND (SELECT COUNT(*) FROM changed) = (SELECT COUNT(*) FROM channels WHERE category_id = $2)
    RETURNING revision
), audited AS (
    INSERT INTO audit_events (actor_user_id, event_type, metadata)
    SELECT $4, 'CHANNELS_REORDERED', jsonb_build_object('category_id', $2, 'count', (SELECT COUNT(*) FROM changed))
    FROM revised
)
SELECT revision FROM revised`

type Row interface{ Scan(...any) error }
type Transaction interface {
	Lock(context.Context, int64) error
	DeferPositions(context.Context) error
	QueryRow(context.Context, string, ...any) Row
	Commit(context.Context) error
	Rollback(context.Context) error
}
type Database interface {
	Begin(context.Context) (Transaction, error)
}
type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }

func (repository Repository) Reorder(context context.Context, input reorderchannels.Input) (reorderchannels.Result, error) {
	transaction, err := repository.database.Begin(context)
	if err != nil {
		return reorderchannels.Result{}, fmt.Errorf("begin channel reorder: %w", err)
	}
	committed := false
	defer func() {
		if !committed {
			_ = transaction.Rollback(context)
		}
	}()
	if err := transaction.Lock(context, topologyLockKey); err != nil {
		return reorderchannels.Result{}, fmt.Errorf("lock channel topology: %w", err)
	}
	if err := transaction.DeferPositions(context); err != nil {
		return reorderchannels.Result{}, fmt.Errorf("defer channel positions: %w", err)
	}
	var result reorderchannels.Result
	err = transaction.QueryRow(context, reorderChannels, input.ExpectedRevision, input.CategoryID, input.IDs, input.ActorID).Scan(&result.Revision)
	if errors.Is(err, pgx.ErrNoRows) {
		return reorderchannels.Result{}, reorderchannels.ErrRevisionConflict
	}
	if err != nil {
		return reorderchannels.Result{}, fmt.Errorf("reorder channels: %w", err)
	}
	if err := transaction.Commit(context); err != nil {
		return reorderchannels.Result{}, fmt.Errorf("commit channel reorder: %w", err)
	}
	committed = true
	return result, nil
}
