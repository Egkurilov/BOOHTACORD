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

func TestHiddenCleanupRetriesAfterFileFailure(t *testing.T) {
	f := newFixture(t)
	ctx := context.Background()
	directory := t.TempDir()
	for _, name := range []string{"text_dead", "dm_dead"} {
		if err := os.Mkdir(filepath.Join(directory, f.keys[name]), 0700); err != nil {
			t.Fatal(err)
		}
	}
	fileStore, err := files.NewFileStore(directory)
	if err != nil {
		t.Fatal(err)
	}
	defer fileStore.Close()
	service := cleanup.New(New(f.pool), fileStore)
	result, err := service.Run(ctx, time.Now().UTC(), 1)
	if err != cleanup.ErrPartialCleanup || result.Failed != 1 || result.Removed != 0 {
		t.Fatalf("result=%+v err=%v", result, err)
	}
	result, err = service.Run(ctx, time.Now().UTC(), 1)
	if err != cleanup.ErrPartialCleanup || result.Failed != 1 || result.Removed != 0 {
		t.Fatalf("second result=%+v err=%v", result, err)
	}
	var leased int
	if err := f.pool.QueryRow(ctx, `SELECT count(*) FROM attachments WHERE state='HIDDEN' AND hidden_cleanup_claim_token IS NOT NULL`).Scan(&leased); err != nil || leased != 2 {
		t.Fatalf("leased=%d err=%v", leased, err)
	}
	result, err = service.Run(ctx, time.Now().UTC(), 1)
	if err != nil || result.Claimed != 0 {
		t.Fatalf("leased rows reclaimed too early: result=%+v err=%v", result, err)
	}
	if _, err := f.pool.Exec(ctx, `UPDATE attachments SET hidden_cleanup_claimed_at=now()-interval '10 minutes' WHERE state='HIDDEN'`); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"text_dead", "dm_dead"} {
		path := filepath.Join(directory, f.keys[name])
		if err := os.Remove(path); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte("data"), 0600); err != nil {
			t.Fatal(err)
		}
	}
	result, err = service.Run(ctx, time.Now().UTC(), 10)
	if err != nil || result.Removed != 2 {
		t.Fatalf("retry result=%+v err=%v", result, err)
	}
}
