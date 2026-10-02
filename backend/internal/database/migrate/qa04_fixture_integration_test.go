package migrate

import (
	"context"
	"testing"
	"time"
	postgresfixture "voice-platform/backend/internal/testsupport/postgres"

	"github.com/jackc/pgx/v5/pgxpool"
)

func newMigrationTestPool(t *testing.T) *pgxpool.Pool {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	t.Cleanup(cancel)
	pool := postgresfixture.New(t, ctx, "TEST_DATABASE_URL", postgresfixture.LoopbackIP)
	return pool
}
