package clientupdates

import (
	"os"
	"path/filepath"
	"testing"
)

func TestStoreKeepsLastValidSnapshot(t *testing.T) {
	path := filepath.Join(t.TempDir(), "catalog.json")
	if err := os.WriteFile(path, []byte(validCatalog), 0o600); err != nil {
		t.Fatal(err)
	}
	store := NewStore(path, nil)
	if err := store.Reload(); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(`{"broken":true}`), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := store.Reload(); err == nil {
		t.Fatal("expected invalid reload")
	}
	if _, ok := store.Policy(Selector{Platform: "web", Distribution: "browser", Channel: "stable", Arch: "any"}); !ok {
		t.Fatal("last valid snapshot was discarded")
	}
}

func TestStoreWithoutValidSnapshotIsUnavailable(t *testing.T) {
	store := NewStore(filepath.Join(t.TempDir(), "missing.json"), nil)
	if _, ok := store.Policy(Selector{}); ok {
		t.Fatal("unexpected snapshot")
	}
}
