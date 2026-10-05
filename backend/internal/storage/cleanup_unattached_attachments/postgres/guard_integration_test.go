package cleanupunattachedattachmentspostgres

import (
	"context"
	"github.com/google/uuid"
	"testing"
	cleanup "voice-platform/backend/internal/storage/cleanup_unattached_attachments"
	fixture "voice-platform/backend/internal/testsupport/postgres"
)

func TestGuardPreservesNewLinkThenFinalizesExactlyOnce(t *testing.T) {
	ctx := context.Background()
	pool := fixture.New(t, ctx, "TEST_DATABASE_URL", fixture.LoopbackOrLocalhost)
	for _, statement := range []string{
		`CREATE TABLE attachments(id uuid PRIMARY KEY,storage_key uuid NOT NULL,state text NOT NULL)`,
		`CREATE TABLE message_attachments(attachment_id uuid REFERENCES attachments(id))`,
		`CREATE TABLE direct_message_attachments(attachment_id uuid REFERENCES attachments(id))`,
		`CREATE TABLE audit_events(event_type text,metadata jsonb)`,
	} {
		if _, err := pool.Exec(ctx, statement); err != nil {
			t.Fatal(err)
		}
	}
	c := cleanup.Candidate{ID: uuid.NewString(), Key: uuid.NewString()}
	if _, err := pool.Exec(ctx, `INSERT INTO attachments VALUES($1,$2,'DELETING')`, c.ID, c.Key); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, `INSERT INTO message_attachments VALUES($1)`, c.ID); err != nil {
		t.Fatal(err)
	}
	removed := 0
	remove := func(string) error { removed++; return nil }
	r := New(pool)
	if err := r.FinalizeWithFile(ctx, c, remove); err == nil || removed != 0 {
		t.Fatal("new link lost file")
	}
	if _, err := pool.Exec(ctx, `DELETE FROM message_attachments WHERE attachment_id=$1`, c.ID); err != nil {
		t.Fatal(err)
	}
	if err := r.FinalizeWithFile(ctx, c, remove); err != nil || removed != 1 {
		t.Fatal("valid cleanup failed", err)
	}
	if err := r.FinalizeWithFile(ctx, c, remove); err == nil || removed != 1 {
		t.Fatal("repeated finalization removed again")
	}
	var audits int
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM audit_events`).Scan(&audits); err != nil || audits != 1 {
		t.Fatal("duplicate removal audit", err)
	}
}
