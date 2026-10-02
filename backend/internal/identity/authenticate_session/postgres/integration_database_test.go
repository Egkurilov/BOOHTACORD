package sessionpostgres

import (
	"context"
	"testing"
	"time"
	postgresfixture "voice-platform/backend/internal/testsupport/postgres"

	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/database/migrate"
)

func newSessionFixture(t *testing.T) *pgxpool.Pool {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	pool := postgresfixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", postgresfixture.LoopbackIP)
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal(err)
	}
	return pool
}
