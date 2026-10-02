package clientupdates

import (
	"context"
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
}

func NewStore(path string, allowedHosts []string) *Store {
	return &Store{path: path, allowedHosts: allowedHosts}
}

func (store *Store) Reload() error {
	file, err := os.Open(store.path)
	if err != nil {
		return fmt.Errorf("open client update catalog: %w", err)
	}
	defer file.Close()
	catalog, err := Parse(file, store.allowedHosts)
	if err != nil {
		return err
	}
	store.mutex.Lock()
	store.snapshot = catalog
	store.mutex.Unlock()
	return nil
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
