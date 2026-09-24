package replayeventpostgres

import (
	"context"
	"errors"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func TestJournalMigrationReplayAndCurrentACL(t *testing.T) {
	url := os.Getenv("TEST_DATABASE_URL")
	if url == "" {
		t.Skip("TEST_DATABASE_URL is required")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	admin, err := pgxpool.New(ctx, url)
	if err != nil {
		t.Fatal(err)
	}
	defer admin.Close()
	schema := "be14_" + strings.ReplaceAll(uuid.NewString(), "-", "")
	if _, err := admin.Exec(ctx, "CREATE SCHEMA "+schema); err != nil {
		t.Fatal(err)
	}
	defer admin.Exec(context.Background(), "DROP SCHEMA "+schema+" CASCADE")
	config, err := pgxpool.ParseConfig(url)
	if err != nil {
		t.Fatal(err)
	}
	config.ConnConfig.RuntimeParams["search_path"] = schema
	db, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	migration, err := os.ReadFile("../../../database/migrate/migrations/0036_create_realtime_events.sql")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(ctx, string(migration)); err != nil {
		t.Fatal(err)
	}
	for _, statement := range []string{
		`CREATE TABLE users (id uuid PRIMARY KEY, blocked_at timestamptz)`,
		`CREATE TABLE channels (id uuid PRIMARY KEY, kind text, archived_at timestamptz)`,
		`CREATE TABLE direct_messages (id uuid PRIMARY KEY, participant_one_id uuid, participant_two_id uuid)`,
		`CREATE TABLE voice_leases (id uuid PRIMARY KEY, user_id uuid)`,
	} {
		if _, err := db.Exec(ctx, statement); err != nil {
			t.Fatal(err)
		}
	}
	accountA, accountB, outsider, dmID := uuid.NewString(), uuid.NewString(), uuid.NewString(), uuid.NewString()
	for _, id := range []string{accountA, accountB, outsider} {
		if _, err := db.Exec(ctx, `INSERT INTO users(id) VALUES($1::uuid)`, id); err != nil {
			t.Fatal(err)
		}
	}
	if _, err := db.Exec(ctx, `INSERT INTO direct_messages VALUES ($1::uuid,$2::uuid,$3::uuid)`, dmID, accountA, accountB); err != nil {
		t.Fatal(err)
	}
	repository, epoch := New(db), uuid.NewString()
	first := eventhub.Event{EventID: uuid.NewString(), Kind: "direct_message.message_created", OccurredAt: time.Now().UTC(), Payload: map[string]any{"direct_message_id": dmID, "message_id": uuid.NewString()}}
	second := eventhub.Event{EventID: uuid.NewString(), Kind: "direct_message.message_deleted", OccurredAt: time.Now().UTC(), Payload: map[string]any{"direct_message_id": dmID, "message_id": uuid.NewString(), "revision": 2}}
	for _, event := range []eventhub.Event{first, second, second} {
		if err := repository.Append(ctx, event, []string{accountA, accountB}, epoch); err != nil {
			t.Fatal(err)
		}
	}
	replayed, err := repository.Replay(ctx, accountA, first.EventID, epoch, ReplayLimit)
	if err != nil || len(replayed) != 1 || replayed[0].EventID != second.EventID {
		t.Fatalf("replay=%#v error=%v", replayed, err)
	}
	if _, err := repository.Replay(ctx, outsider, first.EventID, epoch, ReplayLimit); !errors.Is(err, ErrInvalidCursor) {
		t.Fatalf("outsider cursor error=%v", err)
	}
	if _, err := repository.Replay(ctx, accountA, first.EventID, uuid.NewString(), ReplayLimit); !errors.Is(err, ErrDifferentEpoch) {
		t.Fatalf("restart error=%v", err)
	}
	if allowed, err := repository.Authorize(ctx, accountA, second); err != nil || !allowed {
		t.Fatalf("participant ACL=%v, %v", allowed, err)
	}
	if allowed, err := repository.Authorize(ctx, outsider, second); err != nil || allowed {
		t.Fatalf("third-party ACL=%v, %v", allowed, err)
	}
	if _, err := db.Exec(ctx, `UPDATE users SET blocked_at=now() WHERE id=$1::uuid`, accountA); err != nil {
		t.Fatal(err)
	}
	if allowed, err := repository.Authorize(ctx, accountA, second); err != nil || allowed {
		t.Fatalf("revoked ACL=%v, %v", allowed, err)
	}
	if _, err := db.Exec(ctx, `UPDATE realtime_events SET stored_at=now()-interval '8 days' WHERE id=$1::uuid`, first.EventID); err != nil {
		t.Fatal(err)
	}
	if _, err := repository.Replay(ctx, accountA, first.EventID, epoch, ReplayLimit); !errors.Is(err, ErrExpiredCursor) {
		t.Fatalf("expired cursor error=%v", err)
	}
}
