package descriptionpostgres

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PoolDatabase struct{ pool *pgxpool.Pool }

func NewPoolDatabase(pool *pgxpool.Pool) PoolDatabase { return PoolDatabase{pool: pool} }
func (database PoolDatabase) Begin(ctx context.Context) (Transaction, error) {
	tx, err := database.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	return poolTransaction{tx: tx}, nil
}

type poolTransaction struct{ tx pgx.Tx }

func (transaction poolTransaction) Lock(ctx context.Context, key int64) error {
	_, err := transaction.tx.Exec(ctx, "SELECT pg_advisory_xact_lock($1)", key)
	return err
}
func (transaction poolTransaction) QueryRow(ctx context.Context, statement string, args ...any) Row {
	return transaction.tx.QueryRow(ctx, statement, args...)
}
func (transaction poolTransaction) Commit(ctx context.Context) error {
	return transaction.tx.Commit(ctx)
}
func (transaction poolTransaction) Rollback(ctx context.Context) error {
	err := transaction.tx.Rollback(ctx)
	if err == pgx.ErrTxClosed {
		return nil
	}
	if err != nil {
		return fmt.Errorf("rollback transaction: %w", err)
	}
	return nil
}
