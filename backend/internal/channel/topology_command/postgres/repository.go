package topologycommandpostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	topologycommand "voice-platform/backend/internal/channel/topology_command"
)

const selectReceipt = `
SELECT client_request_id::text, operation, intent_hash, resource_id::text,
 resource_type, result_state, topology_revision, response_status
FROM topology_command_receipts
WHERE actor_id = $1 AND client_request_id = $2`

const insertReceipt = `
INSERT INTO topology_command_receipts (
 actor_id, client_request_id, operation, intent_hash, resource_id,
 resource_type, result_state, topology_revision, response_status
) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`

type Row interface{ Scan(...any) error }
type Database interface {
	QueryRow(context.Context, string, ...any) Row
}

type CommandTransaction interface {
	QueryRow(context.Context, string, ...any) Row
	Exec(context.Context, string, ...any) error
}

type ReceiptReader interface {
	QueryRow(context.Context, string, ...any) Row
}

type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }

func (repository Repository) ReadOwn(ctx context.Context, actorID, requestID string) (topologycommand.Receipt, error) {
	return scanReceipt(repository.database.QueryRow(ctx, selectReceipt, actorID, requestID))
}

func scanReceipt(row Row) (topologycommand.Receipt, error) {
	var receipt topologycommand.Receipt
	err := row.Scan(&receipt.ClientRequestID, &receipt.Operation, &receipt.IntentHash, &receipt.ResourceID, &receipt.ResourceType, &receipt.ResultState, &receipt.TopologyRevision, &receipt.ResponseStatus)
	if errors.Is(err, pgx.ErrNoRows) {
		return receipt, topologycommand.ErrNotFound
	}
	if err != nil {
		return receipt, fmt.Errorf("read topology receipt: %w", err)
	}
	return receipt, nil
}

type Recorder struct{}

func (Recorder) Find(ctx context.Context, transaction ReceiptReader, actorID, requestID string) (topologycommand.Receipt, error) {
	return scanReceipt(transaction.QueryRow(ctx, selectReceipt, actorID, requestID))
}

func (Recorder) Record(ctx context.Context, transaction CommandTransaction, actorID string, receipt topologycommand.Receipt) error {
	err := transaction.Exec(ctx, insertReceipt, actorID, receipt.ClientRequestID, receipt.Operation, receipt.IntentHash, receipt.ResourceID, receipt.ResourceType, receipt.ResultState, receipt.TopologyRevision, receipt.ResponseStatus)
	if err != nil {
		return fmt.Errorf("record topology receipt: %w", err)
	}
	return nil
}

func (Recorder) CheckExisting(receipt topologycommand.Receipt, intentHash string) (topologycommand.Receipt, error) {
	if receipt.IntentHash != intentHash {
		return topologycommand.Receipt{}, topologycommand.ErrKeyReused
	}
	return receipt, nil
}
