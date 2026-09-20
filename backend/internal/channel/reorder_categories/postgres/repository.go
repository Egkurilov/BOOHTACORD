package reorderpostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"voice-platform/backend/internal/channel/reorder_categories"
)

const topologyLockKey int64 = 441903817

const reorderCategories = `
WITH state AS (
    SELECT revision FROM channel_topology_state
    WHERE singleton = TRUE AND revision = $1
), requested AS (
    SELECT id::uuid AS id, (ordinality - 1)::integer AS position
    FROM unnest($2::text[]) WITH ORDINALITY AS requested_ids(id, ordinality)
), valid AS (
    SELECT (SELECT COUNT(*) FROM requested) = (SELECT COUNT(*) FROM categories) AS complete
), changed AS (
    UPDATE categories AS category
    SET position = requested.position, updated_at = now()
    FROM requested, state, valid
    WHERE category.id = requested.id AND valid.complete
    RETURNING category.id
), revised AS (
    UPDATE channel_topology_state
    SET revision = revision + 1
    WHERE singleton = TRUE
      AND revision = $1
      AND EXISTS (SELECT 1 FROM state)
      AND (SELECT COUNT(*) FROM changed) = (SELECT COUNT(*) FROM categories)
    RETURNING revision
), audited AS (
    INSERT INTO audit_events (actor_user_id, event_type, metadata)
    SELECT $3, 'CATEGORIES_REORDERED', jsonb_build_object('count', (SELECT COUNT(*) FROM changed))
    FROM revised
)
SELECT revision FROM revised`

type Row interface {
	Scan(...any) error
}

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

type Repository struct {
	database Database
}

func New(database Database) Repository {
	return Repository{database: database}
}

func (repository Repository) Reorder(context context.Context, input reordercategories.Input) (reordercategories.Result, error) {
	transaction, err := repository.database.Begin(context)
	if err != nil {
		return reordercategories.Result{}, fmt.Errorf("begin category reorder: %w", err)
	}
	committed := false
	defer func() {
		if !committed {
			_ = transaction.Rollback(context)
		}
	}()
	if err := transaction.Lock(context, topologyLockKey); err != nil {
		return reordercategories.Result{}, fmt.Errorf("lock channel topology: %w", err)
	}
	if err := transaction.DeferPositions(context); err != nil {
		return reordercategories.Result{}, fmt.Errorf("defer category positions: %w", err)
	}
	var result reordercategories.Result
	err = transaction.QueryRow(context, reorderCategories, input.ExpectedRevision, input.IDs, input.ActorID).Scan(&result.Revision)
	if errors.Is(err, pgx.ErrNoRows) {
		return reordercategories.Result{}, reordercategories.ErrRevisionConflict
	}
	if err != nil {
		return reordercategories.Result{}, fmt.Errorf("reorder categories: %w", err)
	}
	if err := transaction.Commit(context); err != nil {
		return reordercategories.Result{}, fmt.Errorf("commit category reorder: %w", err)
	}
	committed = true
	return result, nil
}
