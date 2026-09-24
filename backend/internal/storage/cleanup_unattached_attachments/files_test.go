package cleanupunattachedattachments

import (
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"
)

const testKey = "f8a73959-b6e1-4a14-a998-f107d5e10033"

func TestFileStoreRejectsTraversalSymlinksAndDirectories(t *testing.T) {
	directory := t.TempDir()
	store, err := NewFileStore(directory)
	if err != nil {
		t.Fatal(err)
	}
	defer store.Close()
	if err := store.Remove("../outside"); !errors.Is(err, ErrInvalidKey) {
		t.Fatalf("traversal error = %v", err)
	}
	outside := filepath.Join(t.TempDir(), "outside")
	if err := os.WriteFile(outside, []byte("retain"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(outside, filepath.Join(directory, testKey)); err == nil {
		if err := store.Remove(testKey); !errors.Is(err, ErrUnsafeFile) {
			t.Fatalf("symlink error = %v", err)
		}
		if bytes, err := os.ReadFile(outside); err != nil || string(bytes) != "retain" {
			t.Fatalf("outside file changed: %v", err)
		}
		if err := os.Remove(filepath.Join(directory, testKey)); err != nil {
			t.Fatal(err)
		}
	}
	if err := os.Mkdir(filepath.Join(directory, testKey), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := store.Remove(testKey); !errors.Is(err, ErrUnsafeFile) {
		t.Fatalf("directory error = %v", err)
	}
}

func TestFileStoreAgeCheckAndMissingFileRetry(t *testing.T) {
	directory := t.TempDir()
	store, err := NewFileStore(directory)
	if err != nil {
		t.Fatal(err)
	}
	defer store.Close()
	cutoff := time.Date(2026, 9, 23, 12, 0, 0, 0, time.UTC)
	path := filepath.Join(directory, testKey)
	if err := os.WriteFile(path, []byte("private"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.Chtimes(path, cutoff, cutoff); err != nil {
		t.Fatal(err)
	}
	if old, err := store.OldRegular(testKey, cutoff); err != nil || old {
		t.Fatalf("exact cutoff old = %v, error = %v", old, err)
	}
	before := cutoff.Add(-time.Second)
	if err := os.Chtimes(path, before, before); err != nil {
		t.Fatal(err)
	}
	if old, err := store.OldRegular(testKey, cutoff); err != nil || !old {
		t.Fatalf("old file old = %v, error = %v", old, err)
	}
	if err := store.Remove(testKey); err != nil {
		t.Fatal(err)
	}
	if err := store.Remove(testKey); err != nil {
		t.Fatalf("missing retry error = %v", err)
	}
}
