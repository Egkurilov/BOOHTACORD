package downloadtextattachment

import (
	"errors"
	"io"
	"os"
	"path/filepath"
	"testing"
)

func TestFileStoreOpensOnlyMeasuredPrivateRegularFile(t *testing.T) {
	directory := t.TempDir()
	key := storageKey
	if err := os.WriteFile(filepath.Join(directory, key), []byte("safe bytes"), 0o600); err != nil {
		t.Fatal(err)
	}
	store, err := NewFileStore(directory)
	if err != nil {
		t.Fatal(err)
	}
	reader, err := store.Open(key, 10)
	if err != nil {
		t.Fatal(err)
	}
	defer reader.Close()
	bytes, err := io.ReadAll(reader)
	if err != nil || string(bytes) != "safe bytes" {
		t.Fatalf("bytes = %q, error = %v", bytes, err)
	}
}

func TestFileStoreRejectsMissingOrWrongSizeObject(t *testing.T) {
	directory := t.TempDir()
	if err := os.WriteFile(filepath.Join(directory, storageKey), []byte("tiny"), 0o600); err != nil {
		t.Fatal(err)
	}
	store, err := NewFileStore(directory)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := store.Open(storageKey, 10); !errors.Is(err, ErrFileUnavailable) {
		t.Fatalf("size error = %v", err)
	}
	if _, err := store.Open("not-a-key", 0); !errors.Is(err, ErrInvalidStorageKey) {
		t.Fatalf("key error = %v", err)
	}
}
