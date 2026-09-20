package finalizestagedtextattachment

import (
	"errors"
	"os"
	"path/filepath"
	"testing"
)

const storageKey = "b1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"

func TestFileStoreMovesStagedBytesToPrivateRandomName(t *testing.T) {
	staging, unattached := t.TempDir(), t.TempDir()
	source := filepath.Join(staging, "upload.part")
	if err := os.WriteFile(source, []byte("bytes"), 0o600); err != nil {
		t.Fatal(err)
	}
	store, err := NewFileStore(staging, unattached)
	if err != nil {
		t.Fatal(err)
	}
	if err := store.Move(source, storageKey); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(source); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("source error = %v", err)
	}
	bytes, err := os.ReadFile(filepath.Join(unattached, storageKey))
	if err != nil || string(bytes) != "bytes" {
		t.Fatalf("bytes = %q, error = %v", bytes, err)
	}
}

func TestFileStoreRejectsPathOutsideStagingDirectory(t *testing.T) {
	staging, unattached, outside := t.TempDir(), t.TempDir(), t.TempDir()
	source := filepath.Join(outside, "upload.part")
	if err := os.WriteFile(source, []byte("bytes"), 0o600); err != nil {
		t.Fatal(err)
	}
	store, err := NewFileStore(staging, unattached)
	if err != nil {
		t.Fatal(err)
	}
	if err := store.Move(source, storageKey); !errors.Is(err, ErrInvalidTemporaryPath) {
		t.Fatalf("error = %v", err)
	}
	if _, err := os.Stat(source); err != nil {
		t.Fatalf("source error = %v", err)
	}
}
