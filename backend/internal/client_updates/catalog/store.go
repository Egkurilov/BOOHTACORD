package clientupdates

import (
	"bytes"
	"context"
	"crypto/sha256"
	"fmt"
	"log/slog"
	"os"
	"sync"
	"time"
)

type Store struct {
	path         string
	allowedHosts []string
	mutex        sync.RWMutex
	snapshot     *Catalog
	snapshotHash [sha256.Size]byte
	observer     Observer
}

type Observer interface {
	ObserveClientUpdateCheck(platform, result string)
	ObserveClientUpdateCatalogReload(result string, revision int)
}

func NewStore(path string, allowedHosts []string, observers ...Observer) *Store {
	var observer Observer
	if len(observers) > 0 {
		observer = observers[0]
	}
	return &Store{path: path, allowedHosts: allowedHosts, observer: observer}
}

func (store *Store) Reload() error {
	payload, err := os.ReadFile(store.path)
	if err != nil {
		store.observeReload("failure", 0)
		return fmt.Errorf("open client update catalog: %w", err)
	}
	catalog, err := Parse(bytes.NewReader(payload), store.allowedHosts)
	if err != nil {
		store.observeReload("failure", 0)
		return err
	}
	digest := sha256.Sum256(payload)
	store.mutex.Lock()
	if store.snapshot != nil && catalog.Revision < store.snapshot.Revision {
		store.mutex.Unlock()
		store.observeReload("failure", catalog.Revision)
		return fmt.Errorf("client update catalog revision decreased")
	}
	if store.snapshot != nil && catalog.Revision == store.snapshot.Revision {
		if digest != store.snapshotHash {
			store.mutex.Unlock()
			store.observeReload("failure", catalog.Revision)
			return fmt.Errorf("client update catalog revision reused with different bytes")
		}
		store.mutex.Unlock()
		return nil
	}
	store.snapshot = catalog
	store.snapshotHash = digest
	store.mutex.Unlock()
	store.observeReload("success", catalog.Revision)
	return nil
}

func (store *Store) observeReload(result string, revision int) {
	if store.observer != nil {
		store.observer.ObserveClientUpdateCatalogReload(result, revision)
	}
}

func (store *Store) Policy(selector Selector) (Policy, bool) {
	store.mutex.RLock()
	snapshot := store.snapshot
	store.mutex.RUnlock()
	if snapshot == nil {
		return Policy{}, false
	}
	return snapshot.Select(selector)
}

func (store *Store) Start(ctx context.Context) {
	if err := store.Reload(); err != nil {
		slog.Warn("client update catalog unavailable", "error", err)
	}
	go func() {
		ticker := time.NewTicker(10 * time.Second)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				if err := store.Reload(); err != nil {
					slog.Warn("client update catalog reload failed", "error", err)
				}
			}
		}
	}()
}
