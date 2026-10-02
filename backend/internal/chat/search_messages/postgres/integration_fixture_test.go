package searchmessagespostgres

import (
	"context"
	"testing"
	"time"
	postgresfixture "voice-platform/backend/internal/testsupport/postgres"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/database/migrate"
)

type searchFixture struct {
	pool      *pgxpool.Pool
	actorID   string
	peerID    string
	adminID   string
	channelID string
	dmID      string
}

func newSearchFixture(t *testing.T) searchFixture {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	t.Cleanup(cancel)
	pool := postgresfixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", postgresfixture.LoopbackIP)
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal("run embedded migrations:", err)
	}
	fixture := searchFixture{pool: pool, actorID: uuid.NewString(), peerID: uuid.NewString(), adminID: uuid.NewString(), channelID: uuid.NewString(), dmID: uuid.NewString()}
	return fixture
}
