package finalizeclosedvoicechannelpostgres

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PoolDatabase struct{ pool *pgxpool.Pool }

func NewPoolDatabase(pool *pgxpool.Pool) PoolDatabase { return PoolDatabase{pool: pool} }

func (database PoolDatabase) Query(ctx context.Context, statement string, arguments ...any) (Rows, error) {
	return database.pool.Query(ctx, statement, arguments...)
}

func (database PoolDatabase) Begin(ctx context.Context) (Transaction, error) {
	transaction, err := database.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	return poolTransaction{transaction: transaction}, nil
}

type poolTransaction struct{ transaction pgx.Tx }

func (transaction poolTransaction) Lock(ctx context.Context, key int64) error {
	_, err := transaction.transaction.Exec(ctx, "SELECT pg_advisory_xact_lock($1)", key)
	return err
}
func (transaction poolTransaction) QueryRow(ctx context.Context, statement string, arguments ...any) Row {
	return transaction.transaction.QueryRow(ctx, statement, arguments...)
}
func (transaction poolTransaction) Commit(ctx context.Context) error {
	return transaction.transaction.Commit(ctx)
}
func (transaction poolTransaction) Rollback(ctx context.Context) error {
	err := transaction.transaction.Rollback(ctx)
	if errors.Is(err, pgx.ErrTxClosed) {
		return nil
	}
	return err
}
