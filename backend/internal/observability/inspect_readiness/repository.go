package inspectreadiness

import (
	"context"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PoolDatabase struct{ Pool *pgxpool.Pool }

func (d PoolDatabase) Inspect(ctx context.Context) (int64, error) {
	if err := d.Pool.Ping(ctx); err != nil {
		return 0, err
	}
	var count int64
	err := d.Pool.QueryRow(ctx, `SELECT count(*) FROM voice_sfu_revocations WHERE completed_at IS NULL`).Scan(&count)
	return count, err
}
