package coalescepresencesnapshot

import (
	"context"

	"time"
)

func (g *Gate) SnapshotRooms(ctx context.Context, ids []string) (Snapshot, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	requested, key := canonicalScope(ids)
	g.mu.Lock()
	g.expire()
	if f := g.cached[key]; f != nil {
		g.observe("cached")
		result, err := copySnapshot(f.data), f.err
		g.mu.Unlock()
		return result, err
	}
	f := g.pending[key]
	if f == nil {
		if len(g.pending) >= MaxActiveScopes {
			g.mu.Unlock()
			g.observe("overloaded")
			return nil, ErrOverloaded
		}
		fetchCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), 3*time.Second)
		f = &flight{key: key, done: make(chan struct{}), cancel: cancel, generation: g.generation}
		g.pending[key] = f
		g.observe("started")
		go g.fetch(fetchCtx, f, requested)
	}
	if f.waiters > 0 {
		g.observe("shared")
	}
	f.waiters++
	g.mu.Unlock()
	defer g.release(f)
	select {
	case <-ctx.Done():
		g.observe("canceled")
		return nil, ctx.Err()
	case <-f.done:
		if err := ctx.Err(); err != nil {
			return nil, err
		}
		return copySnapshot(f.data), f.err
	}
}

func (g *Gate) expire() {
	for key, f := range g.cached {
		if !g.now().Before(f.expires) {
			delete(g.cached, key)
		}
	}
}

func (g *Gate) release(f *flight) {
	g.mu.Lock()
	defer g.mu.Unlock()
	f.waiters--
	if f.waiters == 0 {
		f.cancel()
	}
}

// Verified webhooks invalidate observations including an in-flight cache fill.
func (g *Gate) Invalidate() {
	g.mu.Lock()
	defer g.mu.Unlock()
	g.generation++
	clear(g.cached)
}
