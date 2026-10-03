package channelpostgres

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PoolDatabase struct {
	pool *pgxpool.Pool
}

func NewPoolDatabase(pool *pgxpool.Pool) PoolDatabase {
	return PoolDatabase{pool: pool}
}

func (database PoolDatabase) Begin(context context.Context) (Transaction, error) {
	transaction, err := database.pool.Begin(context)
	if err != nil {
		return nil, err
	}
	return poolTransaction{transaction: transaction}, nil
}

type poolTransaction struct {
	transaction pgx.Tx
}

func (transaction poolTransaction) Lock(context context.Context, key int64) error {
	_, err := transaction.transaction.Exec(context, "SELECT pg_advisory_xact_lock($1)", key)
	return err
}

func (transaction poolTransaction) QueryRow(context context.Context, statement string, arguments ...any) Row {
	return transaction.transaction.QueryRow(context, statement, arguments...)
}

func (transaction poolTransaction) Exec(context context.Context, statement string, arguments ...any) error {
	_, err := transaction.transaction.Exec(context, statement, arguments...)
	return err
}

func (transaction poolTransaction) Commit(context context.Context) error {
	return transaction.transaction.Commit(context)
}

func (transaction poolTransaction) Rollback(context context.Context) error {
	err := transaction.transaction.Rollback(context)
	if err == pgx.ErrTxClosed {
		return nil
	}
	return fmt.Errorf("rollback transaction: %w", err)
}
