package observeusage

import (
	"context"
	"sync"
	"sync/atomic"
	"time"
)

const cacheLimit = 16384

type Tracker struct {
	store    Store
	now      func() time.Time
	mu       sync.Mutex
	day      time.Time
	seen     map[string]struct{}
	failures atomic.Int64
}

func NewTracker(store Store, now func() time.Time) *Tracker {
	return &Tracker{store: store, now: now, seen: make(map[string]struct{})}
}

// Record affects statistics only. Authentication must survive a telemetry write failure.
func (t *Tracker) Record(ctx context.Context, account string) {
	if t == nil || account == "" {
		return
	}
	now := t.now()
	day := Day(now)
	t.mu.Lock()
	if !t.day.Equal(day) {
		t.day, t.seen = day, make(map[string]struct{})
	}
	_, seen := t.seen[account]
	t.mu.Unlock()
	if seen {
		return
	}
	bounded, cancel := context.WithTimeout(ctx, 200*time.Millisecond)
	defer cancel()
	if err := t.store.Record(bounded, account, now); err != nil {
		t.failures.Add(1)
		return
	}
	t.mu.Lock()
	defer t.mu.Unlock()
	if t.day.Equal(day) && len(t.seen) < cacheLimit {
		t.seen[account] = struct{}{}
	}
}
