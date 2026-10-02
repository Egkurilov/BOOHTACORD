package createtextmessagepostgres

import (
	"context"
	"fmt"
	"testing"
	"time"
	postgresfixture "voice-platform/backend/internal/testsupport/postgres"

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
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	t.Cleanup(cancel)
	pool := postgresfixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", postgresfixture.LoopbackIP)
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
