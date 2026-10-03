package channelpostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"voice-platform/backend/internal/channel/create_channel"
	topologycommand "voice-platform/backend/internal/channel/topology_command"
	topologycommandpostgres "voice-platform/backend/internal/channel/topology_command/postgres"
)

const topologyLockKey int64 = 441903817

const insertChannel = `
WITH category AS (
    SELECT id FROM categories WHERE id = $2
), created AS (
    INSERT INTO channels (id, category_id, name, kind, position)
    SELECT $1, category.id, $3, $4,
           COALESCE((SELECT MAX(position) + 1 FROM channels WHERE category_id = category.id), 0)
    FROM category
    RETURNING id, category_id, name, kind, position
), revised AS (
    INSERT INTO channel_topology_state (singleton, revision)
    SELECT TRUE, 1 FROM created
    ON CONFLICT (singleton) DO UPDATE
    SET revision = channel_topology_state.revision + 1
    RETURNING revision
), audited AS (
    INSERT INTO audit_events (actor_user_id, event_type, metadata)
    SELECT $5, 'CHANNEL_CREATED', jsonb_build_object('channel_id', id::text, 'category_id', category_id::text)
    FROM created
)
SELECT created.id::text, created.category_id::text, created.name, created.kind, created.position, revised.revision
FROM created CROSS JOIN revised`

type Row interface {
	Scan(...any) error
}

type Transaction interface {
	Lock(context.Context, int64) error
	QueryRow(context.Context, string, ...any) Row
	Exec(context.Context, string, ...any) error
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

func (repository Repository) Create(context context.Context, request createchannel.Request) (createchannel.Result, error) {
	transaction, err := repository.database.Begin(context)
	if err != nil {
		return createchannel.Result{}, fmt.Errorf("begin channel creation: %w", err)
	}
	committed := false
	defer func() {
		if !committed {
			_ = transaction.Rollback(context)
		}
	}()
	if err := transaction.Lock(context, topologyLockKey); err != nil {
		return createchannel.Result{}, fmt.Errorf("lock channel topology: %w", err)
	}
	if request.ClientRequestID != "" {
		recorder := topologycommandpostgres.Recorder{}
		receipt, findErr := recorder.Find(context, receiptTransaction{transaction}, request.ActorID, request.ClientRequestID)
		if findErr == nil {
			receipt, checkErr := recorder.CheckExisting(receipt, request.IntentHash)
			if checkErr != nil {
				return createchannel.Result{}, checkErr
			}
			if err := transaction.Commit(context); err != nil {
				return createchannel.Result{}, err
			}
			committed = true
			return createchannel.Result{ID: receipt.ResourceID, CategoryID: request.CategoryID, Name: request.Name, Kind: request.Kind, Revision: receipt.TopologyRevision}, nil
		}
		if !errors.Is(findErr, topologycommand.ErrNotFound) {
			return createchannel.Result{}, findErr
		}
	}
	var result createchannel.Result
	var kind string
	err = transaction.QueryRow(context, insertChannel, request.ID, request.CategoryID, request.Name, string(request.Kind), request.ActorID).Scan(&result.ID, &result.CategoryID, &result.Name, &kind, &result.Position, &result.Revision)
	if errors.Is(err, pgx.ErrNoRows) {
		return createchannel.Result{}, createchannel.ErrCategoryNotFound
	}
	if err != nil {
		return createchannel.Result{}, fmt.Errorf("insert channel: %w", err)
	}
	result.Kind = createchannel.Kind(kind)
	if request.ClientRequestID != "" {
		operation, resourceType := topologycommand.OperationTextCreate, "TEXT_CHANNEL"
		if request.Kind == createchannel.KindVoice {
			operation, resourceType = topologycommand.OperationVoiceCreate, "VOICE_CHANNEL"
		}
		receipt := topologycommand.Receipt{ClientRequestID: request.ClientRequestID, Operation: operation, IntentHash: request.IntentHash, ResourceID: result.ID, ResourceType: resourceType, ResultState: "ACTIVE", TopologyRevision: result.Revision, ResponseStatus: 201}
		if err := (topologycommandpostgres.Recorder{}).Record(context, receiptTransaction{transaction}, request.ActorID, receipt); err != nil {
			return createchannel.Result{}, err
		}
	}
	if err := transaction.Commit(context); err != nil {
		return createchannel.Result{}, fmt.Errorf("commit channel creation: %w", err)
	}
	committed = true
	return result, nil
}
