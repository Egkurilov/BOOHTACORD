package renamepostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"voice-platform/backend/internal/channel/rename_category"
)

const topologyLockKey int64 = 441903817

const renameCategory = `
WITH state AS (
    SELECT revision FROM channel_topology_state
    WHERE singleton = TRUE AND revision = $1
), changed AS (
    UPDATE categories
    SET name = $3, updated_at = now()
    WHERE id = $2 AND EXISTS (SELECT 1 FROM state)
    RETURNING id, name
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
    SELECT $4, 'CATEGORY_RENAMED', jsonb_build_object('category_id', id::text)
    FROM changed CROSS JOIN revised
)
SELECT changed.id::text, changed.name, revised.revision
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

func (repository Repository) Rename(context context.Context, input renamecategory.Input) (renamecategory.Result, error) {
	transaction, err := repository.database.Begin(context)
	if err != nil {
		return renamecategory.Result{}, fmt.Errorf("begin category rename: %w", err)
	}
	committed := false
	defer func() {
		if !committed {
			_ = transaction.Rollback(context)
		}
	}()
	if err := transaction.Lock(context, topologyLockKey); err != nil {
		return renamecategory.Result{}, fmt.Errorf("lock channel topology: %w", err)
	}
	var result renamecategory.Result
	err = transaction.QueryRow(context, renameCategory, input.ExpectedRevision, input.CategoryID, input.Name, input.ActorID).Scan(&result.ID, &result.Name, &result.Revision)
	if errors.Is(err, pgx.ErrNoRows) {
		return renamecategory.Result{}, renamecategory.ErrRevisionConflict
	}
	if err != nil {
		return renamecategory.Result{}, fmt.Errorf("rename category: %w", err)
	}
	if err := transaction.Commit(context); err != nil {
		return renamecategory.Result{}, fmt.Errorf("commit category rename: %w", err)
	}
	committed = true
	return result, nil
}
