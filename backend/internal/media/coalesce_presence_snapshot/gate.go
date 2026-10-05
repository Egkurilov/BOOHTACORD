package coalescepresencesnapshot

import (
	"context"
	"slices"
	"strings"
	"sync"
	"time"
	presence "voice-platform/backend/internal/media/snapshot_livekit_presence"
)

const TTL = 250 * time.Millisecond

type Snapshot = map[string][]presence.ConnectedLease
type Source interface {
	SnapshotRooms(context.Context, []string) (Snapshot, error)
}
type flight struct {
	key     string
	done    chan struct{}
	data    Snapshot
	err     error
	expires time.Time
}

// Retains at most one exact scope and one pending fetch. Other scopes bypass retention.
type Gate struct {
	mu              sync.Mutex
	source          Source
	pending, cached *flight
	now             func() time.Time
}

func New(source Source) *Gate { return &Gate{source: source, now: time.Now} }

func (g *Gate) SnapshotRooms(ctx context.Context, ids []string) (Snapshot, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	requested := append([]string(nil), ids...)
	slices.Sort(requested)
	requested = slices.Compact(requested)
	key := strings.Join(requested, ",")
	g.mu.Lock()
	if f := g.cached; f != nil && f.key == key && g.now().Before(f.expires) {
		result := copySnapshot(f.data)
		g.mu.Unlock()
		return result, nil
	}
	if g.pending != nil && g.pending.key != key {
		g.mu.Unlock()
		return g.source.SnapshotRooms(ctx, requested)
	}
	f := g.pending
	if f == nil {
		f = &flight{key: key, done: make(chan struct{})}
		g.pending, g.cached = f, nil
		go g.fetch(f, requested)
	}
	g.mu.Unlock()
	select {
	case <-ctx.Done():
		return nil, ctx.Err()
	case <-f.done:
		if err := ctx.Err(); err != nil {
			return nil, err
		}
		return copySnapshot(f.data), f.err
	}
}
