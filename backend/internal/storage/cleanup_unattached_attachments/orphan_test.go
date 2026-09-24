package cleanupunattachedattachments

import (
	"context"
	"testing"
	"time"
)

func TestRecoverOrphanRequiresOldFileAndAbsentMetadata(t *testing.T) {
	now := time.Date(2026, 9, 24, 12, 0, 0, 0, time.UTC)
	store := &fakeStore{exists: true}
	files := &fakeFiles{old: true}
	service := New(store, files)
	if removed, err := service.RecoverOrphan(context.Background(), "key", now); err != nil || removed {
		t.Fatalf("live metadata removed = %v, error = %v", removed, err)
	}
	store.exists = false
	files.old = false
	if removed, err := service.RecoverOrphan(context.Background(), "key", now); err != nil || removed {
		t.Fatalf("fresh file removed = %v, error = %v", removed, err)
	}
	files.old = true
	if removed, err := service.RecoverOrphan(context.Background(), "key", now); err != nil || !removed || len(files.removed) != 1 {
		t.Fatalf("old orphan removed = %v, calls = %v, error = %v", removed, files.removed, err)
	}
}
