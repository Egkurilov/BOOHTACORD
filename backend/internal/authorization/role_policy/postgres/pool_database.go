package rolepolicypostgres

import (
	"context"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PoolDatabase struct{ pool *pgxpool.Pool }

func NewPoolDatabase(pool *pgxpool.Pool) PoolDatabase { return PoolDatabase{pool: pool} }

func (database PoolDatabase) QueryRow(ctx context.Context, statement string, arguments ...any) Row {
	return database.pool.QueryRow(ctx, statement, arguments...)
}

func (database PoolDatabase) Begin(ctx context.Context) (Transaction, error) {
	tx, err := database.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	return poolTransaction{tx}, nil
}

type poolTransaction struct{ tx pgx.Tx }

func (transaction poolTransaction) QueryRow(ctx context.Context, statement string, arguments ...any) Row {
	return transaction.tx.QueryRow(ctx, statement, arguments...)
}
func (transaction poolTransaction) Exec(ctx context.Context, statement string, arguments ...any) error {
	_, err := transaction.tx.Exec(ctx, statement, arguments...)
	return err
}
func (transaction poolTransaction) Commit(ctx context.Context) error {
	return transaction.tx.Commit(ctx)
}
func (transaction poolTransaction) Rollback(ctx context.Context) error {
	err := transaction.tx.Rollback(ctx)
	if err == pgx.ErrTxClosed {
		return nil
	}
	return err
}
