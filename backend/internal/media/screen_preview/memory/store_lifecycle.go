package memory

import (
	"time"

	screenpreview "voice-platform/backend/internal/media/screen_preview"
)

func (store *Store) Commit(leaseID, generation string, revision uint64, body []byte) error {
	if len(body) == 0 || len(body) > screenpreview.MaxJPEGBytes {
		return screenpreview.ErrInvalidJPEG
	}
	store.mu.Lock()
	defer store.mu.Unlock()
	current := store.entries[leaseID]
	if store.closed {
		return ErrClosed
	}
	if current == nil || current.generation != generation || current.reserved != revision {
		return ErrStaleGeneration
	}
	store.clearBytes(current.jpeg)
	current.jpeg = append([]byte(nil), body...)
	current.revision = revision
	current.reserved = 0
	store.expireAfter(leaseID, current)
	return nil
}

func (store *Store) Read(leaseID, generation string) ([]byte, uint64, bool, error) {
	store.mu.Lock()
	defer store.mu.Unlock()
	current := store.entries[leaseID]
	if store.closed {
		return nil, 0, false, ErrClosed
	}
	if current == nil || current.generation != generation {
		return nil, 0, false, ErrStaleGeneration
	}
	if len(current.jpeg) == 0 {
		return nil, 0, false, nil
	}
	return append([]byte(nil), current.jpeg...), current.revision, true, nil
}

func (store *Store) Invalidate(leaseID, generation string) error {
	store.mu.Lock()
	defer store.mu.Unlock()
	current := store.entries[leaseID]
	if current != nil && current.generation == generation {
		store.clearEntry(current)
		delete(store.entries, leaseID)
	}
	return nil
}

func (store *Store) expireAfter(leaseID string, current *entry) {
	if current.timer != nil {
		current.timer.Stop()
	}
	current.timer = time.AfterFunc(store.ttl, func() {
		store.mu.Lock()
		defer store.mu.Unlock()
		if store.entries[leaseID] == current {
			store.clearEntry(current)
			delete(store.entries, leaseID)
		}
	})
}

func (store *Store) clearEntry(current *entry) {
	if current.timer != nil {
		current.timer.Stop()
	}
	store.clearBytes(current.jpeg)
	current.jpeg = nil
}

func (store *Store) clearBytes(body []byte) { clear(body) }

func (store *Store) Close() error {
	store.mu.Lock()
	defer store.mu.Unlock()
	if store.closed {
		return nil
	}
	store.closed = true
	for leaseID, current := range store.entries {
		store.clearEntry(current)
		delete(store.entries, leaseID)
	}
	return nil
}
