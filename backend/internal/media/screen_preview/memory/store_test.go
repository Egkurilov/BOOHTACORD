package memory

import (
	"bytes"
	"errors"
	"testing"
	"time"
)

func TestLatestGenerationOwnsBoundedPreviewAndInvalidation(t *testing.T) {
	now := time.Now()
	store := newStore(func() time.Time { return now }, time.Hour, 0, 2)
	defer store.Close()
	first, err := store.Begin("lease", "track-a")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := store.Reserve("lease", first, 1); err != nil {
		t.Fatal(err)
	}
	original := []byte{1, 2, 3}
	if err := store.Commit("lease", first, 1, original); err != nil {
		t.Fatal(err)
	}
	original[0] = 9
	body, revision, found, err := store.Read("lease", first)
	if err != nil || !found || revision != 1 || !bytes.Equal(body, []byte{1, 2, 3}) {
		t.Fatalf("read = %v, %d, %v, %v", body, revision, found, err)
	}
	body[0] = 8
	body, _, _, _ = store.Read("lease", first)
	if body[0] != 1 {
		t.Fatal("reader mutated cached preview")
	}
	now = now.Add(300 * time.Millisecond)
	second, err := store.Begin("lease", "track-b")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := store.Reserve("lease", first, 2); !errors.Is(err, ErrStaleGeneration) {
		t.Fatalf("old generation upload error = %v", err)
	}
	if err := store.Invalidate("lease", first); err != nil {
		t.Fatal(err)
	}
	if _, _, found, _ := store.Read("lease", second); found {
		t.Fatal("empty generation returned an image")
	}
}

func TestUploadRateAndCapacityAreBounded(t *testing.T) {
	now := time.Now()
	store := newStore(func() time.Time { return now }, time.Hour, 4*time.Second, 1)
	defer store.Close()
	first, err := store.Begin("lease-a", "track-a")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := store.Reserve("lease-a", first, 1); err != nil {
		t.Fatal(err)
	}
	if _, err := store.Reserve("lease-a", first, 2); !errors.Is(err, ErrRateLimited) {
		t.Fatalf("rapid upload error = %v", err)
	}
	if _, err := store.Begin("lease-b", "track-b"); !errors.Is(err, ErrCapacity) {
		t.Fatalf("capacity error = %v", err)
	}
}

func TestPreviewDataExpiresAndCloseClearsStore(t *testing.T) {
	store := newStore(time.Now, 20*time.Millisecond, 0, 2)
	generation, err := store.Begin("lease", "track")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := store.Reserve("lease", generation, 1); err != nil {
		t.Fatal(err)
	}
	if err := store.Commit("lease", generation, 1, []byte{1}); err != nil {
		t.Fatal(err)
	}
	time.Sleep(60 * time.Millisecond)
	if _, _, found, _ := store.Read("lease", generation); found {
		t.Fatal("expired bytes remained available")
	}
	if err := store.Close(); err != nil {
		t.Fatal(err)
	}
	if _, err := store.Begin("other", "track"); !errors.Is(err, ErrClosed) {
		t.Fatalf("closed store error = %v", err)
	}
}
