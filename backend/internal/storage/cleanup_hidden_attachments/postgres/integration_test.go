package cleanuphiddenattachmentspostgres

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"
	cleanup "voice-platform/backend/internal/storage/cleanup_hidden_attachments"
	files "voice-platform/backend/internal/storage/cleanup_unattached_attachments"
)

func TestHiddenCleanupAgainstPostgres(t *testing.T) {
	f := newFixture(t)
	ctx := context.Background()
	directory := t.TempDir()
	for _, key := range f.keys {
		if err := os.WriteFile(filepath.Join(directory, key), []byte("data"), 0600); err != nil {
			t.Fatal(err)
		}
	}
	fileStore, err := files.NewFileStore(directory)
	if err != nil {
		t.Fatal(err)
	}
	defer fileStore.Close()
	result, err := cleanup.New(New(f.pool), fileStore).Run(ctx, time.Now().UTC(), 10)
	if err != nil || result.Claimed != 2 || result.Removed != 2 {
		t.Fatalf("result=%+v err=%v", result, err)
	}
	for _, name := range []string{"text_dead", "dm_dead"} {
		if _, err := os.Stat(filepath.Join(directory, f.keys[name])); !os.IsNotExist(err) {
			t.Fatalf("%s file still exists: %v", name, err)
		}
		var count int
		if err := f.pool.QueryRow(ctx, `SELECT count(*) FROM attachments WHERE storage_key=$1`, f.keys[name]).Scan(&count); err != nil || count != 0 {
			t.Fatalf("%s metadata count=%d err=%v", name, count, err)
		}
	}
	for _, name := range []string{"text_live", "dm_live"} {
		if _, err := os.Stat(filepath.Join(directory, f.keys[name])); err != nil {
			t.Fatalf("%s file missing: %v", name, err)
		}
		var state string
		if err := f.pool.QueryRow(ctx, `SELECT state FROM attachments WHERE storage_key=$1`, f.keys[name]).Scan(&state); err != nil || state != "ATTACHED" {
			t.Fatalf("%s state=%s err=%v", name, state, err)
		}
	}
	var audits int
	if err := f.pool.QueryRow(ctx, `SELECT count(*) FROM audit_events WHERE event_type='HIDDEN_ATTACHMENT_REMOVED'`).Scan(&audits); err != nil || audits != 2 {
		t.Fatalf("audits=%d err=%v", audits, err)
	}
}

func TestHiddenClaimExpiresAndFinalizationRechecksLiveLink(t *testing.T) {
	f := newFixture(t)
	ctx := context.Background()
	repo := New(f.pool)
	first, err := repo.Claim(ctx, time.Now().UTC(), 1)
	if err != nil || len(first) != 1 {
		t.Fatalf("first=%+v err=%v", first, err)
	}
	second, err := repo.Claim(ctx, time.Now().UTC(), 10)
	if err != nil {
		t.Fatal(err)
	}
	for _, candidate := range second {
		if candidate.ID == first[0].ID {
			t.Fatal("unexpired claim was reclaimed")
		}
	}
	if _, err := f.pool.Exec(ctx, `UPDATE attachments SET hidden_cleanup_claimed_at=now()-interval '10 minutes' WHERE id=$1`, first[0].ID); err != nil {
		t.Fatal(err)
	}
	reclaimed, err := repo.Claim(ctx, time.Now().UTC(), 10)
	if err != nil {
		t.Fatal(err)
	}
	var current cleanup.Candidate
	for _, candidate := range reclaimed {
		if candidate.ID == first[0].ID {
			current = candidate
		}
	}
	if current.ID == "" || current.Token == first[0].Token {
		t.Fatalf("expired claim not renewed: %+v", reclaimed)
	}
	// Simulate a malformed out-of-band link; finalization must preserve metadata and write no success audit.
	var id string
	if err := f.pool.QueryRow(ctx, `SELECT id::text FROM attachments WHERE id=$1`, current.ID).Scan(&id); err != nil {
		t.Fatal(err)
	}
	if _, err := f.pool.Exec(ctx, `INSERT INTO message_attachments (message_id,attachment_id,position) VALUES ($1,$2,1)`, f.textLive, id); err != nil {
		if _, err2 := f.pool.Exec(ctx, `INSERT INTO direct_message_attachments (message_id,attachment_id,position) VALUES ($1,$2,1)`, f.dmLive, id); err2 != nil {
			t.Fatalf("cannot create cross-link: %v / %v", err, err2)
		}
	}
	if err := repo.Finalize(ctx, current); err == nil {
		t.Fatal("finalization accepted a live link")
	}
	var count int
	if err := f.pool.QueryRow(ctx, `SELECT count(*) FROM attachments WHERE id=$1`, id).Scan(&count); err != nil || count != 1 {
		t.Fatalf("metadata count=%d err=%v", count, err)
	}
}
