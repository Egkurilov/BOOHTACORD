package finalizeclosedvoicechannelpostgres

import (
	"context"
	"strings"
	"testing"
	"time"
	postgresfixture "voice-platform/backend/internal/testsupport/postgres"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/database/migrate"
)

type integrationFixture struct {
	pool      *pgxpool.Pool
	channelID string
	userID    string
	digest    []byte
}

func newIntegrationFixture(t *testing.T) integrationFixture {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	t.Cleanup(cancel)
	pool := postgresfixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", postgresfixture.LoopbackIP)
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal("run migrations:", err)
	}
	fixture := integrationFixture{pool: pool, channelID: uuid.NewString(), userID: uuid.NewString(), digest: []byte(strings.Repeat("d", 32))}
	categoryID := uuid.NewString()
	seed := []struct {
		sql  string
		args []any
	}{
		{"INSERT INTO users (id, login, display_name, password_hash, role) VALUES ($1, 'voicefinalizer', 'Voice Finalizer', 'test-only', 'MEMBER')", []any{fixture.userID}},
		{"INSERT INTO sessions (token_digest, user_id) VALUES ($1, $2)", []any{fixture.digest, fixture.userID}},
		{"INSERT INTO categories (id, name, position) VALUES ($1, 'General', 0)", []any{categoryID}},
		{"INSERT INTO channels (id, category_id, name, kind, position, admission_closed_at) VALUES ($1, $2, 'Voice', 'VOICE', 0, now())", []any{fixture.channelID, categoryID}},
		{"INSERT INTO channel_topology_state (singleton, revision) VALUES (TRUE, 1)", nil},
	}
	for _, entry := range seed {
		if _, err := pool.Exec(ctx, entry.sql, entry.args...); err != nil {
			t.Fatal("seed test fixture:", err)
		}
	}
	return fixture
}
