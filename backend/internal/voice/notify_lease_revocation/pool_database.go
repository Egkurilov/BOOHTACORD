package notifyleaserevocation

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"
)

type PoolDatabase struct{ pool *pgxpool.Pool }

func NewPoolDatabase(pool *pgxpool.Pool) PoolDatabase { return PoolDatabase{pool: pool} }

func (database PoolDatabase) Query(context context.Context, statement string, arguments ...any) (Rows, error) {
	return database.pool.Query(context, statement, arguments...)
}

func (database PoolDatabase) Exec(context context.Context, statement string, arguments ...any) (int64, error) {
	result, err := database.pool.Exec(context, statement, arguments...)
	return result.RowsAffected(), err
}
