package memory

import (
	"errors"
	"sync"
	"time"

	"github.com/google/uuid"
	screenpreview "voice-platform/backend/internal/media/screen_preview"
)

var (
	ErrStaleGeneration = screenpreview.ErrStaleGeneration
	ErrRateLimited     = screenpreview.ErrRateLimited
	ErrCapacity        = screenpreview.ErrCapacity
	ErrClosed          = errors.New("screen preview store is closed")
)

const maxEntries = 256

type entry struct {
	generation, trackSID string
	revision, reserved   uint64
	jpeg                 []byte
	lastAttempt, created time.Time
	timer                *time.Timer
}
type Store struct {
	mu                  sync.Mutex
	entries             map[string]*entry
	now                 func() time.Time
	ttl, uploadInterval time.Duration
	capacity            int
	closed              bool
}

func New() *Store {
	return newStore(time.Now, screenpreview.PreviewTTL, screenpreview.UploadInterval, maxEntries)
}
func newStore(now func() time.Time, ttl, uploadInterval time.Duration, capacity int) *Store {
	return &Store{entries: make(map[string]*entry), now: now, ttl: ttl, uploadInterval: uploadInterval, capacity: capacity}
}

func (store *Store) Begin(leaseID, trackSID string) (string, error) {
	store.mu.Lock()
	defer store.mu.Unlock()
	if store.closed {
		return "", ErrClosed
	}
	now := store.now()
	previous := store.entries[leaseID]
	if previous == nil && len(store.entries) >= store.capacity {
		return "", ErrCapacity
	}
	if previous != nil && now.Sub(previous.created) < 250*time.Millisecond {
		return "", ErrRateLimited
	}
	if previous != nil {
		store.clearEntry(previous)
	}
	generation, err := uuid.NewRandom()
	if err != nil {
		return "", errors.New("screen preview generation unavailable")
	}
	current := &entry{generation: generation.String(), trackSID: trackSID, created: now}
	store.entries[leaseID] = current
	store.expireAfter(leaseID, current)
	return current.generation, nil
}

func (store *Store) Track(leaseID, generation string) (string, error) {
	store.mu.Lock()
	defer store.mu.Unlock()
	current := store.entries[leaseID]
	if current == nil || current.generation != generation {
		return "", ErrStaleGeneration
	}
	return current.trackSID, nil
}

func (store *Store) Reserve(leaseID, generation string, revision uint64) (string, error) {
	store.mu.Lock()
	defer store.mu.Unlock()
	current := store.entries[leaseID]
	if store.closed {
		return "", ErrClosed
	}
	if current == nil || current.generation != generation {
		return "", ErrStaleGeneration
	}
	now := store.now()
	if revision <= current.revision || revision <= current.reserved {
		return "", ErrStaleGeneration
	}
	if !current.lastAttempt.IsZero() && now.Sub(current.lastAttempt) < store.uploadInterval {
		return "", ErrRateLimited
	}
	current.lastAttempt, current.reserved = now, revision
	return current.trackSID, nil
}
