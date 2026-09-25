package migrate

import (
	"context"
	"sort"
	"strings"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

func TestMigrationsOnEmptyAndExistingPostgresSchemas(t *testing.T) {
	for _, stage := range []string{"empty", "existing"} {
		t.Run(stage, func(t *testing.T) {
			pool := newMigrationTestPool(t)
			ctx := context.Background()
			if stage == "existing" {
				applyMigrationPrefix(t, pool, "0025")
				seedLegacySearchRows(t, pool)
			}
			if err := Run(ctx, pool); err != nil {
				t.Fatal("apply all migrations:", err)
			}
			if err := Run(ctx, pool); err != nil {
				t.Fatal("repeat all migrations:", err)
			}
			var indexes int
			err := pool.QueryRow(ctx, `SELECT count(*) FROM pg_indexes
				WHERE schemaname = current_schema()
				AND indexname IN ('messages_search_idx', 'direct_message_messages_search_idx')`).Scan(&indexes)
			if err != nil || indexes != 2 {
				t.Fatalf("search index count = %d, error = %v", indexes, err)
			}
			if stage == "existing" {
				for _, table := range []string{"messages", "direct_message_messages"} {
					var matches int
					err := pool.QueryRow(ctx, "SELECT count(*) FROM "+table+
						" WHERE search_vector @@ websearch_to_tsquery('simple', 'старый')").Scan(&matches)
					if err != nil || matches != 1 {
						t.Fatalf("%s legacy search matches = %d, error = %v", table, matches, err)
					}
				}
			}
		})
	}
}

func applyMigrationPrefix(t *testing.T, pool *pgxpool.Pool, lastVersion string) {
	t.Helper()
	entries, err := files.ReadDir("migrations")
	if err != nil {
		t.Fatal("list embedded migrations:", err)
	}
	for _, entry := range entries {
		if entry.IsDir() || strings.Compare(entry.Name()[:4], lastVersion) > 0 {
			continue
		}
		statement, err := files.ReadFile("migrations/" + entry.Name())
		if err != nil {
			t.Fatal("read old migration:", err)
		}
		if _, err := pool.Exec(context.Background(), string(statement)); err != nil {
			t.Fatalf("apply old migration %s: %v", entry.Name(), err)
		}
	}
}

func seedLegacySearchRows(t *testing.T, pool *pgxpool.Pool) {
	t.Helper()
	ctx := context.Background()
	insert := func(statement string, args ...any) {
		t.Helper()
		if _, err := pool.Exec(ctx, statement, args...); err != nil {
			t.Fatal("seed legacy row:", err)
		}
	}
	participants := []string{uuid.NewString(), uuid.NewString()}
	sort.Strings(participants)
	insert("INSERT INTO users (id, login, display_name, password_hash, role) VALUES ($1, 'oldone', 'Old One', 'test-only', 'MEMBER')", participants[0])
	insert("INSERT INTO users (id, login, display_name, password_hash, role) VALUES ($1, 'oldtwo', 'Old Two', 'test-only', 'MEMBER')", participants[1])
	categoryID, channelID, dmID := uuid.NewString(), uuid.NewString(), uuid.NewString()
	insert("INSERT INTO categories (id, name, position) VALUES ($1, 'Legacy', 0)", categoryID)
	insert("INSERT INTO channels (id, category_id, name, kind, position) VALUES ($1,$2,'Legacy text','TEXT',0)", channelID, categoryID)
	insert("INSERT INTO direct_messages (id, participant_one_id, participant_two_id) VALUES ($1,$2,$3)", dmID, participants[0], participants[1])
	insert("INSERT INTO messages (id, channel_id, author_id, client_message_id, body) VALUES ($1,$2,$3,$4,'старый текст')", uuid.NewString(), channelID, participants[0], uuid.NewString())
	insert("INSERT INTO direct_message_messages (id, direct_message_id, author_id, client_message_id, body) VALUES ($1,$2,$3,$4,'старый DM')", uuid.NewString(), dmID, participants[1], uuid.NewString())
}
