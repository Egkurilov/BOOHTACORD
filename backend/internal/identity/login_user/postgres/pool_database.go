package loginpostgres

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"
)

type PoolDatabase struct {
	pool *pgxpool.Pool
}

func NewPoolDatabase(pool *pgxpool.Pool) PoolDatabase {
	return PoolDatabase{pool: pool}
}

func (database PoolDatabase) QueryRow(context context.Context, statement string, arguments ...any) Row {
	return database.pool.QueryRow(context, statement, arguments...)
}

func (database PoolDatabase) Exec(context context.Context, statement string, arguments ...any) error {
	_, err := database.pool.Exec(context, statement, arguments...)
	return err
}
