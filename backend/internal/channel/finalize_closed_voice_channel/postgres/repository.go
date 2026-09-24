package finalizeclosedvoicechannelpostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
)

const topologyLockKey int64 = 441903817

type Row interface{ Scan(...any) error }
type Rows interface {
	Next() bool
	Scan(...any) error
	Close()
	Err() error
}
type Transaction interface {
	Lock(context.Context, int64) error
	QueryRow(context.Context, string, ...any) Row
	Commit(context.Context) error
	Rollback(context.Context) error
}
type Database interface {
	Query(context.Context, string, ...any) (Rows, error)
	Begin(context.Context) (Transaction, error)
}

type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }

func (repository Repository) Candidates(ctx context.Context, limit int, after string) ([]string, error) {
	var cursor any
	if after != "" {
		cursor = after
	}
	rows, err := repository.database.Query(ctx, selectCandidates, limit, cursor)
	if err != nil {
		return nil, fmt.Errorf("query closed voice channels: %w", err)
	}
	defer rows.Close()
	channelIDs := make([]string, 0, limit)
	for rows.Next() {
		var channelID string
		if err := rows.Scan(&channelID); err != nil {
			return nil, fmt.Errorf("scan closed voice channel: %w", err)
		}
		channelIDs = append(channelIDs, channelID)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate closed voice channels: %w", err)
	}
	return channelIDs, nil
}

// Finalize returns zero on a concurrent finalization or a guard that is no longer true.
// A nonzero revision is returned only after the transaction commits.
func (repository Repository) Finalize(ctx context.Context, channelID string) (int64, error) {
	transaction, err := repository.database.Begin(ctx)
	if err != nil {
		return 0, fmt.Errorf("begin voice channel finalization: %w", err)
	}
	committed := false
	defer func() {
		if !committed {
			_ = transaction.Rollback(ctx)
		}
	}()
	if err := transaction.Lock(ctx, topologyLockKey); err != nil {
		return 0, fmt.Errorf("lock channel topology: %w", err)
	}
	var revision int64
	err = transaction.QueryRow(ctx, finalizeChannel, channelID).Scan(&revision)
	if errors.Is(err, pgx.ErrNoRows) {
		return 0, nil
	}
	if err != nil {
		return 0, fmt.Errorf("archive closed voice channel: %w", err)
	}
	if err := transaction.Commit(ctx); err != nil {
		return 0, fmt.Errorf("commit voice channel finalization: %w", err)
	}
	committed = true
	return revision, nil
}
