package finalizeclosedvoicechannelpostgres

import (
	"context"
	"net"
	"os"
	"strings"
	"testing"
	"time"

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
	databaseURL := os.Getenv("VOICE_PLATFORM_TEST_DATABASE_URL")
	if databaseURL == "" {
		t.Skip("VOICE_PLATFORM_TEST_DATABASE_URL is not configured")
	}
	config, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		t.Fatal("parse test database URL:", err)
	}
	if host := net.ParseIP(config.ConnConfig.Host); host == nil || !host.IsLoopback() {
		t.Fatal("test database must use a loopback IP address")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	t.Cleanup(cancel)
	admin, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		t.Fatal("open test database:", err)
	}
	if err := admin.Ping(ctx); err != nil {
		admin.Close()
		t.Fatal("ping test database:", err)
	}
	schema := "voice_finalize_" + strings.ReplaceAll(uuid.NewString(), "-", "")
	if _, err := admin.Exec(ctx, "CREATE SCHEMA "+schema); err != nil {
		admin.Close()
		t.Fatal("create test schema:", err)
	}
	isolated := config.Copy()
	if isolated.ConnConfig.RuntimeParams == nil {
		isolated.ConnConfig.RuntimeParams = make(map[string]string)
	}
	isolated.ConnConfig.RuntimeParams["search_path"] = schema
	pool, err := pgxpool.NewWithConfig(ctx, isolated)
	if err != nil {
		t.Fatal("open isolated test pool:", err)
	}
	t.Cleanup(func() {
		pool.Close()
		cleanupCtx, stop := context.WithTimeout(context.Background(), 10*time.Second)
		defer stop()
		if _, err := admin.Exec(cleanupCtx, "DROP SCHEMA "+schema+" CASCADE"); err != nil {
			t.Errorf("drop isolated test schema: %v", err)
		}
		admin.Close()
	})
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
