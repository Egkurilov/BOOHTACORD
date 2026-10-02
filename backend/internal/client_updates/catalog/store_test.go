package clientupdates

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestStoreRejectsRevisionReuseWithDifferentBytes(t *testing.T) {
	path := filepath.Join(t.TempDir(), "catalog.json")
	if err := os.WriteFile(path, []byte(validCatalog), 0o600); err != nil {
		t.Fatal(err)
	}
	store := NewStore(path, nil)
	if err := store.Reload(); err != nil {
		t.Fatal(err)
	}
	changed := []byte(strings.Replace(validCatalog, `"summary":"Update"`, `"summary":"Changed"`, 1))
	if err := os.WriteFile(path, changed, 0o600); err != nil {
		t.Fatal(err)
	}
	if err := store.Reload(); err == nil {
		t.Fatal("revision reuse with different bytes was accepted")
	}
}

func TestStoreRejectsRevisionRollback(t *testing.T) {
	path := filepath.Join(t.TempDir(), "catalog.json")
	if err := os.WriteFile(path, []byte(validCatalog), 0o600); err != nil {
		t.Fatal(err)
	}
	store := NewStore(path, nil)
	if err := store.Reload(); err != nil {
		t.Fatal(err)
	}
	older := []byte(strings.Replace(validCatalog, `"catalog_revision":7`, `"catalog_revision":6`, 1))
	if err := os.WriteFile(path, older, 0o600); err != nil {
		t.Fatal(err)
	}
	if err := store.Reload(); err == nil {
		t.Fatal("catalog revision rollback was accepted")
	}
}

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
