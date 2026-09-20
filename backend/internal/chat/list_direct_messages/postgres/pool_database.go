package listdirectmessagespostgres

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"
)

type PoolDatabase struct{ pool *pgxpool.Pool }

func NewPoolDatabase(pool *pgxpool.Pool) PoolDatabase { return PoolDatabase{pool: pool} }
func (database PoolDatabase) Query(context context.Context, query string, arguments ...any) (Rows, error) {
	return database.pool.Query(context, query, arguments...)
}
