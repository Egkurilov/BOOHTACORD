package categorypostgres

import (
	"context"
	"fmt"

	"voice-platform/backend/internal/channel/create_category"
)

const topologyLockKey int64 = 441903817

const insertCategory = `
WITH created AS (
    INSERT INTO categories (id, name, position)
    SELECT $1, $2, COALESCE((SELECT MAX(position) + 1 FROM categories), 0)
    RETURNING id, name, position
), revised AS (
    INSERT INTO channel_topology_state (singleton, revision)
    SELECT TRUE, 1 FROM created
    ON CONFLICT (singleton) DO UPDATE
    SET revision = channel_topology_state.revision + 1
    RETURNING revision
), audited AS (
    INSERT INTO audit_events (actor_user_id, event_type, metadata)
    SELECT $3, 'CATEGORY_CREATED', jsonb_build_object('category_id', id::text) FROM created
)
SELECT created.id::text, created.name, created.position, revised.revision
FROM created CROSS JOIN revised`

type Row interface {
	Scan(...any) error
}

type Transaction interface {
	Lock(context.Context, int64) error
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

func (repository Repository) Create(context context.Context, request createcategory.Request) (createcategory.Result, error) {
	transaction, err := repository.database.Begin(context)
	if err != nil {
		return createcategory.Result{}, fmt.Errorf("begin category creation: %w", err)
	}
	committed := false
	defer func() {
		if !committed {
			_ = transaction.Rollback(context)
		}
	}()
	if err := transaction.Lock(context, topologyLockKey); err != nil {
		return createcategory.Result{}, fmt.Errorf("lock channel topology: %w", err)
	}
	var result createcategory.Result
	if err := transaction.QueryRow(context, insertCategory, request.ID, request.Name, request.ActorID).Scan(&result.ID, &result.Name, &result.Position, &result.Revision); err != nil {
		return createcategory.Result{}, fmt.Errorf("insert category: %w", err)
	}
	if err := transaction.Commit(context); err != nil {
		return createcategory.Result{}, fmt.Errorf("commit category creation: %w", err)
	}
	committed = true
	return result, nil
}
