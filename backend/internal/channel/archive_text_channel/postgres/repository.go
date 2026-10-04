package archivepostgres

import (
	"context"
	"errors"
	"fmt"
	"github.com/jackc/pgx/v5"
	"voice-platform/backend/internal/channel/archive_text_channel"
	topologycommand "voice-platform/backend/internal/channel/topology_command"
	topologycommandpostgres "voice-platform/backend/internal/channel/topology_command/postgres"
)

const topologyLockKey int64 = 441903817

const insertTextArchiveReceipt = `INSERT INTO topology_command_receipts (actor_id,client_request_id,operation,intent_hash,resource_id,resource_type,result_state,topology_revision,response_status) VALUES ($1,$2,$3,$4,$5,'TEXT_CHANNEL','ARCHIVED',$6,200) RETURNING 1`

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

func (repository Repository) Archive(context context.Context, input archivetextchannel.Input) (archivetextchannel.Result, error) {
	transaction, err := repository.database.Begin(context)
	if err != nil {
		return archivetextchannel.Result{}, fmt.Errorf("begin text channel archive: %w", err)
	}
	committed := false
	defer func() {
		if !committed {
			_ = transaction.Rollback(context)
		}
	}()
	if err := transaction.Lock(context, topologyLockKey); err != nil {
		return archivetextchannel.Result{}, fmt.Errorf("lock channel topology: %w", err)
	}
	if input.ClientRequestID != "" {
		recorder := topologycommandpostgres.Recorder{}
		receipt, findErr := recorder.Find(context, receiptTransaction{transaction}, input.ActorID, input.ClientRequestID)
		if findErr == nil {
			receipt, checkErr := recorder.CheckExisting(receipt, input.IntentHash)
			if checkErr != nil {
				return archivetextchannel.Result{}, checkErr
			}
			if err := transaction.Commit(context); err != nil {
				return archivetextchannel.Result{}, err
			}
			committed = true
			return archivetextchannel.Result{ID: receipt.ResourceID, Revision: receipt.TopologyRevision}, nil
		}
		if !errors.Is(findErr, topologycommand.ErrNotFound) {
			return archivetextchannel.Result{}, findErr
		}
	}
	var result archivetextchannel.Result
	err = transaction.QueryRow(context, archiveTextChannel, input.ExpectedRevision, input.ChannelID, input.ActorID).Scan(&result.ID, &result.Revision)
	if errors.Is(err, pgx.ErrNoRows) {
		return archivetextchannel.Result{}, archivetextchannel.ErrRevisionConflict
	}
	if err != nil {
		return archivetextchannel.Result{}, fmt.Errorf("archive text channel: %w", err)
	}
	if input.ClientRequestID != "" {
		var inserted int
		if err := transaction.QueryRow(context, insertTextArchiveReceipt, input.ActorID, input.ClientRequestID, topologycommand.OperationTextArchive, input.IntentHash, result.ID, result.Revision).Scan(&inserted); err != nil {
			return archivetextchannel.Result{}, err
		}
	}
	if err := transaction.Commit(context); err != nil {
		return archivetextchannel.Result{}, fmt.Errorf("commit text channel archive: %w", err)
	}
	committed = true
	return result, nil
}
