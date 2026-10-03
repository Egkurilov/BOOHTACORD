package deleteemptycategorypostgres

import (
	"context"
	"errors"
	"fmt"
	"github.com/jackc/pgx/v5"
	deleteemptycategory "voice-platform/backend/internal/channel/delete_empty_category"
	topologycommand "voice-platform/backend/internal/channel/topology_command"
	topologycommandpostgres "voice-platform/backend/internal/channel/topology_command/postgres"
)

const topologyLockKey int64 = 441903817
const deleteEmptyCategory = `WITH state AS (SELECT revision FROM channel_topology_state WHERE singleton = TRUE AND revision = $1), deleted AS (DELETE FROM categories category WHERE id = $2 AND EXISTS (SELECT 1 FROM state) AND NOT EXISTS (SELECT 1 FROM channels WHERE category_id = category.id) RETURNING id), revised AS (UPDATE channel_topology_state SET revision = revision + 1 WHERE singleton = TRUE AND revision = $1 AND EXISTS (SELECT 1 FROM deleted) RETURNING revision), audited AS (INSERT INTO audit_events (actor_user_id,event_type,metadata) SELECT $3,'EMPTY_CATEGORY_DELETED',jsonb_build_object('category_id',id::text) FROM deleted CROSS JOIN revised) SELECT deleted.id::text,revised.revision FROM deleted CROSS JOIN revised`
const insertCategoryDeleteReceipt = `INSERT INTO topology_command_receipts (actor_id,client_request_id,operation,intent_hash,resource_id,resource_type,result_state,topology_revision,response_status) VALUES ($1,$2,$3,$4,$5,'CATEGORY','DELETED',$6,200) RETURNING 1`

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

func New(database Database) Repository { return Repository{database} }
func (r Repository) Delete(ctx context.Context, input deleteemptycategory.Input) (deleteemptycategory.Result, error) {
	tx, err := r.database.Begin(ctx)
	if err != nil {
		return deleteemptycategory.Result{}, fmt.Errorf("begin empty category delete: %w", err)
	}
	committed := false
	defer func() {
		if !committed {
			_ = tx.Rollback(ctx)
		}
	}()
	if err := tx.Lock(ctx, topologyLockKey); err != nil {
		return deleteemptycategory.Result{}, fmt.Errorf("lock channel topology: %w", err)
	}
	if input.ClientRequestID != "" {
		recorder := topologycommandpostgres.Recorder{}
		receipt, findErr := recorder.Find(ctx, receiptTransaction{tx}, input.ActorID, input.ClientRequestID)
		if findErr == nil {
			receipt, checkErr := recorder.CheckExisting(receipt, input.IntentHash)
			if checkErr != nil {
				return deleteemptycategory.Result{}, checkErr
			}
			if err := tx.Commit(ctx); err != nil {
				return deleteemptycategory.Result{}, err
			}
			committed = true
			return deleteemptycategory.Result{ID: receipt.ResourceID, Revision: receipt.TopologyRevision}, nil
		}
		if !errors.Is(findErr, topologycommand.ErrNotFound) {
			return deleteemptycategory.Result{}, findErr
		}
	}
	var out deleteemptycategory.Result
	err = tx.QueryRow(ctx, deleteEmptyCategory, input.ExpectedRevision, input.CategoryID, input.ActorID).Scan(&out.ID, &out.Revision)
	if errors.Is(err, pgx.ErrNoRows) {
		return deleteemptycategory.Result{}, deleteemptycategory.ErrRevisionConflict
	}
	if err != nil {
		return deleteemptycategory.Result{}, fmt.Errorf("delete empty category: %w", err)
	}
	if input.ClientRequestID != "" {
		var inserted int
		if err := tx.QueryRow(ctx, insertCategoryDeleteReceipt, input.ActorID, input.ClientRequestID, topologycommand.OperationCategoryDelete, input.IntentHash, out.ID, out.Revision).Scan(&inserted); err != nil {
			return deleteemptycategory.Result{}, err
		}
	}
	if err = tx.Commit(ctx); err != nil {
		return deleteemptycategory.Result{}, fmt.Errorf("commit empty category delete: %w", err)
	}
	committed = true
	return out, nil
}
