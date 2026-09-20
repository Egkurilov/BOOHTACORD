package deleteemptycategorypostgres

import (
	"context"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PoolDatabase struct{ pool *pgxpool.Pool }

func NewPoolDatabase(pool *pgxpool.Pool) PoolDatabase { return PoolDatabase{pool} }
func (d PoolDatabase) Begin(ctx context.Context) (Transaction, error) {
	tx, err := d.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	return poolTransaction{tx}, nil
}

type poolTransaction struct{ pgx.Tx }

func (t poolTransaction) Lock(ctx context.Context, key int64) error {
	_, err := t.Exec(ctx, "SELECT pg_advisory_xact_lock($1)", key)
	return err
}
func (t poolTransaction) QueryRow(ctx context.Context, q string, args ...any) Row {
	return t.Tx.QueryRow(ctx, q, args...)
}
