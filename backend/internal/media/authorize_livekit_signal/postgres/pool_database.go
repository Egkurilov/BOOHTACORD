package authorizelivekitsignalpostgres

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"
	locked "voice-platform/backend/internal/media/read_locked_voice_admission"
)

type PoolDatabase struct{ pool *pgxpool.Pool }

func NewPoolDatabase(pool *pgxpool.Pool) PoolDatabase { return PoolDatabase{pool: pool} }

func (database PoolDatabase) QueryRow(context context.Context, statement string, arguments ...any) Row {
	return locked.ForLease(database.pool, context, arguments[0].(string), statement, arguments...)
}
