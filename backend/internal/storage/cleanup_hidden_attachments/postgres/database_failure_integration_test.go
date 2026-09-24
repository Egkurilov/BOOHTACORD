package cleanuphiddenattachmentspostgres

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"
	files "voice-platform/backend/internal/storage/cleanup_unattached_attachments"
)

func TestHiddenCleanupRetriesWhenDatabaseFailsAfterUnlink(t *testing.T) {
	f := newFixture(t)
	ctx := context.Background()
	repo := New(f.pool)
	claimed, err := repo.Claim(ctx, time.Now().UTC(), 1)
	if err != nil || len(claimed) != 1 {
		t.Fatalf("claim=%+v err=%v", claimed, err)
	}
	directory := t.TempDir()
	path := filepath.Join(directory, claimed[0].Key)
	if err := os.WriteFile(path, []byte("data"), 0600); err != nil {
		t.Fatal(err)
	}
	fileStore, err := files.NewFileStore(directory)
	if err != nil {
		t.Fatal(err)
	}
	defer fileStore.Close()
	if err := fileStore.Remove(claimed[0].Key); err != nil {
		t.Fatal(err)
	}
	if _, err := f.pool.Exec(ctx, `ALTER TABLE audit_events ADD CONSTRAINT reject_hidden_audit CHECK (event_type <> 'HIDDEN_ATTACHMENT_REMOVED')`); err != nil {
		t.Fatal(err)
	}
	if err := repo.Finalize(ctx, claimed[0]); err == nil {
		t.Fatal("finalization succeeded despite audit failure")
	}
	var links, metadata int
	if err := f.pool.QueryRow(ctx, `SELECT count(*) FROM attachments WHERE id=$1`, claimed[0].ID).Scan(&metadata); err != nil || metadata != 1 {
		t.Fatalf("metadata=%d err=%v", metadata, err)
	}
	if err := f.pool.QueryRow(ctx, `SELECT (SELECT count(*) FROM message_attachments WHERE attachment_id=$1)+(SELECT count(*) FROM direct_message_attachments WHERE attachment_id=$1)`, claimed[0].ID).Scan(&links); err != nil || links != 1 {
		t.Fatalf("links=%d err=%v", links, err)
	}
	if _, err := f.pool.Exec(ctx, `ALTER TABLE audit_events DROP CONSTRAINT reject_hidden_audit`); err != nil {
		t.Fatal(err)
	}
	if _, err := f.pool.Exec(ctx, `UPDATE attachments SET hidden_cleanup_claimed_at=now()-interval '10 minutes' WHERE id=$1`, claimed[0].ID); err != nil {
		t.Fatal(err)
	}
	ready, err := repo.Claim(ctx, time.Now().UTC(), 10)
	if err != nil {
		t.Fatal(err)
	}
	for _, candidate := range ready {
		if candidate.ID != claimed[0].ID {
			continue
		}
		if err := fileStore.Remove(candidate.Key); err != nil {
			t.Fatal(err)
		}
		if err := repo.Finalize(ctx, candidate); err != nil {
			t.Fatal(err)
		}
		if _, err := os.Stat(path); !os.IsNotExist(err) {
			t.Fatalf("missing file not idempotent: %v", err)
		}
		return
	}
	t.Fatal("expired claim was not recovered")
}
