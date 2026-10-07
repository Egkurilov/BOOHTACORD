package publishscreendescriptorpostgres

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"math"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"voice-platform/backend/internal/media/publish_screen_descriptor"
)

type Row interface{ Scan(...any) error }
type Transaction interface {
	QueryRow(context.Context, string, ...any) Row
	Exec(context.Context, string, ...any) error
	Commit(context.Context) error
	Rollback(context.Context) error
}
type Database interface {
	Begin(context.Context) (Transaction, error)
}
type Publisher interface {
	Publish(context.Context, string, string, string) error
}
type Repository struct {
	database  Database
	publisher Publisher
}

func New(database Database, publisher Publisher) Repository {
	return Repository{database: database, publisher: publisher}
}

func (repository Repository) Apply(ctx context.Context, principal publish_screen_descriptor.Principal, leaseID, origin string, input publish_screen_descriptor.Descriptor) error {
	if uuid.Validate(principal.AccountID) != nil || uuid.Validate(leaseID) != nil || origin == "" || !publish_screen_descriptor.Validate(input) || input.Scope.OperationRevision > math.MaxInt64 {
		return publish_screen_descriptor.ErrInvalid
	}
	tx, err := repository.database.Begin(ctx)
	if err != nil {
		return publish_screen_descriptor.ErrUnavailable
	}
	defer func() { _ = tx.Rollback(ctx) }()
	var accountID, channelID string
	var current int64
	var currentHash []byte
	err = tx.QueryRow(ctx, lockLease, leaseID, principal.AccountID, principal.SessionDigest[:]).Scan(&accountID, &channelID, &current, &currentHash)
	if errors.Is(err, pgx.ErrNoRows) {
		return publish_screen_descriptor.ErrDenied
	}
	if err != nil {
		return publish_screen_descriptor.ErrUnavailable
	}
	input.Scope.OriginID, input.Scope.AccountID = origin, accountID
	input.Scope.RoomID = "voice:" + channelID
	body, err := json.Marshal(input)
	if err != nil {
		return publish_screen_descriptor.ErrInvalid
	}
	digest := sha256.Sum256(body)
	revision := int64(input.Scope.OperationRevision)
	if revision < current {
		return publish_screen_descriptor.ErrStale
	}
	if revision == current && (len(currentHash) != len(digest) || string(currentHash) != string(digest[:])) {
		return publish_screen_descriptor.ErrConflict
	}
	if err := repository.publisher.Publish(ctx, leaseID, channelID, string(body)); err != nil {
		return publish_screen_descriptor.ErrUnavailable
	}
	if revision > current {
		if err := tx.Exec(ctx, saveReceipt, revision, digest[:], leaseID); err != nil {
			return publish_screen_descriptor.ErrUnavailable
		}
	}
	if err := tx.Commit(ctx); err != nil {
		return publish_screen_descriptor.ErrUnavailable
	}
	return nil
}

type PoolDatabase struct {
	pool interface {
		Begin(context.Context) (pgx.Tx, error)
	}
}

func NewPoolDatabase(pool interface {
	Begin(context.Context) (pgx.Tx, error)
}) PoolDatabase {
	return PoolDatabase{pool: pool}
}
func (database PoolDatabase) Begin(ctx context.Context) (Transaction, error) {
	tx, err := database.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	return pgxTransaction{tx: tx}, nil
}

type pgxTransaction struct{ tx pgx.Tx }

func (transaction pgxTransaction) QueryRow(ctx context.Context, query string, args ...any) Row {
	return transaction.tx.QueryRow(ctx, query, args...)
}
func (transaction pgxTransaction) Exec(ctx context.Context, query string, args ...any) error {
	_, err := transaction.tx.Exec(ctx, query, args...)
	return err
}
func (transaction pgxTransaction) Commit(ctx context.Context) error {
	return transaction.tx.Commit(ctx)
}
func (transaction pgxTransaction) Rollback(ctx context.Context) error {
	return transaction.tx.Rollback(ctx)
}
