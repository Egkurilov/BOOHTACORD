package registerpostgres

import (
	"context"

	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PoolExecutor struct {
	pool *pgxpool.Pool
}

func NewPoolExecutor(pool *pgxpool.Pool) PoolExecutor {
	return PoolExecutor{pool: pool}
}

func (executor PoolExecutor) Exec(context context.Context, statement string, arguments ...any) (pgconn.CommandTag, error) {
	return executor.pool.Exec(context, statement, arguments...)
}
