package advancetextchannelreadcursorpostgres

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

type cursorFixture struct {
	pool                                                  *pgxpool.Pool
	actorID, otherID, channelID, secondChannelID, voiceID string
}

func newCursorFixture(t *testing.T) cursorFixture {
	t.Helper()
	databaseURL := os.Getenv("VOICE_PLATFORM_TEST_DATABASE_URL")
	if databaseURL == "" {
		t.Skip("VOICE_PLATFORM_TEST_DATABASE_URL is not configured")
	}
	config, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		t.Fatal("parse test URL:", err)
	}
	address := net.ParseIP(config.ConnConfig.Host)
	if address == nil || !address.IsLoopback() {
		t.Fatal("test database must use loopback IP")
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
	schema := "voice_it_" + strings.ReplaceAll(uuid.NewString(), "-", "")
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
		_, _ = admin.Exec(ctx, "DROP SCHEMA "+schema+" CASCADE")
		admin.Close()
		t.Fatal("open isolated pool:", err)
	}
	t.Cleanup(func() {
		pool.Close()
		cleanup, stop := context.WithTimeout(context.Background(), 10*time.Second)
		defer stop()
		if _, err := admin.Exec(cleanup, "DROP SCHEMA "+schema+" CASCADE"); err != nil {
			t.Errorf("drop test schema: %v", err)
		}
		admin.Close()
	})
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal("run migrations:", err)
	}
	fixture := cursorFixture{pool: pool, actorID: uuid.NewString(), otherID: uuid.NewString(), channelID: uuid.NewString(), secondChannelID: uuid.NewString(), voiceID: uuid.NewString()}
	categoryID := uuid.NewString()
	seed := []struct {
		query string
		args  []any
	}{
		{"INSERT INTO users (id, login, display_name, password_hash, role) VALUES ($1, 'cursor_actor', 'Cursor Actor', 'test-only', 'MEMBER')", []any{fixture.actorID}},
		{"INSERT INTO users (id, login, display_name, password_hash, role) VALUES ($1, 'cursor_other', 'Cursor Other', 'test-only', 'MEMBER')", []any{fixture.otherID}},
		{"INSERT INTO categories (id, name, position) VALUES ($1, 'General', 0)", []any{categoryID}},
		{"INSERT INTO channels (id, category_id, name, kind, position) VALUES ($1, $2, 'Text', 'TEXT', 0)", []any{fixture.channelID, categoryID}},
		{"INSERT INTO channels (id, category_id, name, kind, position) VALUES ($1, $2, 'Other', 'TEXT', 1)", []any{fixture.secondChannelID, categoryID}},
		{"INSERT INTO channels (id, category_id, name, kind, position) VALUES ($1, $2, 'Voice', 'VOICE', 2)", []any{fixture.voiceID, categoryID}},
	}
	for _, entry := range seed {
		if _, err := pool.Exec(ctx, entry.query, entry.args...); err != nil {
			t.Fatal("seed test database:", err)
		}
	}
	return fixture
}

func (fixture cursorFixture) message(t *testing.T, channelID, authorID string) string {
	t.Helper()
	id := uuid.NewString()
	_, err := fixture.pool.Exec(context.Background(), "INSERT INTO messages (id, channel_id, author_id, client_message_id, body) VALUES ($1, $2, $3, $4, 'test')", id, channelID, authorID, uuid.NewString())
	if err != nil {
		t.Fatal("insert message:", err)
	}
	return id
}
