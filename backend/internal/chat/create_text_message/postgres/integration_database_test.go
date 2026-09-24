package createtextmessagepostgres

import (
	"context"
	"fmt"
	"net"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/database/migrate"
)

type textMessageFixture struct {
	pool         *pgxpool.Pool
	authorID     string
	channelID    string
	attachmentID string
}

func newTextMessageFixture(t *testing.T) textMessageFixture {
	t.Helper()
	databaseURL := os.Getenv("VOICE_PLATFORM_TEST_DATABASE_URL")
	if databaseURL == "" {
		t.Skip("VOICE_PLATFORM_TEST_DATABASE_URL is not configured")
	}
	config, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		t.Fatal("parse test database URL:", err)
	}
	address := net.ParseIP(config.ConnConfig.Host)
	if address == nil || !address.IsLoopback() {
		t.Fatal("test database must use a loopback IP address")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	t.Cleanup(cancel)
	admin, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		t.Fatal("connect to test database:", err)
	}
	if err := admin.Ping(ctx); err != nil {
		admin.Close()
		t.Fatal("ping test database:", err)
	}
	schema := "voice_it_" + strings.ReplaceAll(uuid.NewString(), "-", "")
	if _, err := admin.Exec(ctx, "CREATE SCHEMA "+schema); err != nil {
		admin.Close()
		t.Fatal("create isolated test schema:", err)
	}
	isolatedConfig := config.Copy()
	if isolatedConfig.ConnConfig.RuntimeParams == nil {
		isolatedConfig.ConnConfig.RuntimeParams = make(map[string]string)
	}
	isolatedConfig.ConnConfig.RuntimeParams["search_path"] = schema
	pool, err := pgxpool.NewWithConfig(ctx, isolatedConfig)
	if err != nil {
		_, _ = admin.Exec(ctx, "DROP SCHEMA "+schema+" CASCADE")
		admin.Close()
		t.Fatal("open isolated test pool:", err)
	}
	t.Cleanup(func() {
		pool.Close()
		cleanupContext, cleanupCancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cleanupCancel()
		if _, err := admin.Exec(cleanupContext, "DROP SCHEMA "+schema+" CASCADE"); err != nil {
			t.Errorf("drop isolated test schema: %v", err)
		}
		admin.Close()
	})
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal("run embedded migrations:", err)
	}
	fixture := textMessageFixture{pool: pool, authorID: uuid.NewString(), channelID: uuid.NewString(), attachmentID: uuid.NewString()}
	categoryID := uuid.NewString()
	seed := []struct {
		statement string
		arguments []any
	}{
		{"INSERT INTO users (id, login, display_name, password_hash, role) VALUES ($1, 'textsender', 'Text Sender', 'test-only', 'MEMBER')", []any{fixture.authorID}},
		{"INSERT INTO categories (id, name, position) VALUES ($1, 'General', 0)", []any{categoryID}},
		{"INSERT INTO channels (id, category_id, name, kind, position) VALUES ($1, $2, 'Text', 'TEXT', 0)", []any{fixture.channelID, categoryID}},
		{"INSERT INTO attachments (id, owner_id, channel_id, original_name, storage_key, byte_size, state) VALUES ($1, $2, $3, 'test.txt', $4, 1, 'UNATTACHED')", []any{fixture.attachmentID, fixture.authorID, fixture.channelID, uuid.NewString()}},
	}
	for index, entry := range seed {
		if _, err := pool.Exec(ctx, entry.statement, entry.arguments...); err != nil {
			t.Fatal(fmt.Sprintf("seed test row %d:", index), err)
		}
	}
	return fixture
}
