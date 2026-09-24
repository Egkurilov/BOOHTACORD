package cleanupunattachedattachmentspostgres

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

func TestClaimAgainstDisposablePostgresSchema(t *testing.T) {
	url := os.Getenv("TEST_DATABASE_URL")
	if url == "" {
		t.Skip("TEST_DATABASE_URL is required for the PostgreSQL race test")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	admin, err := pgxpool.New(ctx, url)
	if err != nil {
		t.Fatal(err)
	}
	defer admin.Close()
	schema := "be11_" + strings.ReplaceAll(uuid.NewString(), "-", "")
	if _, err := admin.Exec(ctx, "CREATE SCHEMA "+schema); err != nil {
		t.Fatal(err)
	}
	defer admin.Exec(context.Background(), "DROP SCHEMA "+schema+" CASCADE")
	config, err := pgxpool.ParseConfig(url)
	if err != nil {
		t.Fatal(err)
	}
	config.ConnConfig.RuntimeParams["search_path"] = schema
	pool, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		t.Fatal(err)
	}
	defer pool.Close()
	for _, ddl := range []string{
		`CREATE TABLE attachments (id uuid PRIMARY KEY, storage_key uuid UNIQUE NOT NULL, state text NOT NULL, created_at timestamptz NOT NULL)`,
		`CREATE TABLE message_attachments (attachment_id uuid REFERENCES attachments(id))`,
		`CREATE TABLE direct_message_attachments (attachment_id uuid REFERENCES attachments(id))`,
		`CREATE TABLE audit_events (event_type text NOT NULL, metadata jsonb NOT NULL)`,
	} {
		if _, err := pool.Exec(ctx, ddl); err != nil {
			t.Fatal(err)
		}
	}
	migration, err := os.ReadFile(filepath.Join("..", "..", "..", "database", "migrate", "migrations", "0038_add_unattached_cleanup_retry_schedule.sql"))
	if err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, string(migration)); err != nil {
		t.Fatal(err)
	}
	now := time.Now().UTC()
	old, fresh, textLinked, dmLinked, racing := uuid.New(), uuid.New(), uuid.New(), uuid.New(), uuid.New()
	for _, item := range []struct {
		id  uuid.UUID
		age time.Duration
	}{{old, 25 * time.Hour}, {fresh, time.Hour}, {textLinked, 25 * time.Hour}, {dmLinked, 25 * time.Hour}, {racing, 25 * time.Hour}} {
		if _, err := pool.Exec(ctx, `INSERT INTO attachments VALUES ($1,$2,'UNATTACHED',$3)`, item.id, uuid.New(), now.Add(-item.age)); err != nil {
			t.Fatal(err)
		}
	}
	if _, err := pool.Exec(ctx, `INSERT INTO message_attachments VALUES ($1)`, textLinked); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, `INSERT INTO direct_message_attachments VALUES ($1)`, dmLinked); err != nil {
		t.Fatal(err)
	}
	tx, err := pool.Begin(ctx)
	if err != nil {
		t.Fatal(err)
	}
	defer tx.Rollback(context.Background())
	if _, err := tx.Exec(ctx, `SELECT id FROM attachments WHERE id=$1 FOR UPDATE`, racing); err != nil {
		t.Fatal(err)
	}
	repo := New(pool)
	claimed, err := repo.Claim(ctx, now.Add(-24*time.Hour), 10)
	if err != nil || len(claimed) != 1 || claimed[0].ID != old.String() {
		t.Fatalf("claimed = %+v, error = %v", claimed, err)
	}
	if _, err := tx.Exec(ctx, `UPDATE attachments SET state='ATTACHED' WHERE id=$1`, racing); err != nil {
		t.Fatal(err)
	}
	if err := tx.Commit(ctx); err != nil {
		t.Fatal(err)
	}
	again, err := repo.Claim(ctx, now.Add(-24*time.Hour), 10)
	if err != nil || len(again) != 0 {
		t.Fatalf("early retry = %+v, error = %v", again, err)
	}
	if _, err := pool.Exec(ctx, `UPDATE attachments SET unattached_cleanup_retry_after=clock_timestamp()-interval '1 second' WHERE id=$1`, old); err != nil {
		t.Fatal(err)
	}
	again, err = repo.Claim(ctx, now.Add(-24*time.Hour), 10)
	if err != nil || len(again) != 1 || again[0].ID != old.String() {
		t.Fatalf("due retry = %+v, error = %v", again, err)
	}
	if err := repo.Finalize(ctx, old.String()); err != nil {
		t.Fatal(err)
	}
	for _, id := range []uuid.UUID{fresh, textLinked, dmLinked, racing} {
		var state string
		if err := pool.QueryRow(ctx, `SELECT state FROM attachments WHERE id=$1`, id).Scan(&state); err != nil || state == "DELETING" {
			t.Fatal(fmt.Sprintf("protected row %s state = %s, error = %v", id, state, err))
		}
	}
	assertFairBatch(t, ctx, pool, repo, now)
}
