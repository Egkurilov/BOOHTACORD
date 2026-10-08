package coalescepresencesnapshot

import (
	"context"
	"errors"
)

func (g *Gate) fetch(ctx context.Context, f *flight, ids []string) {
	defer f.cancel()
	data, err := g.source.SnapshotRooms(ctx, ids)
	g.mu.Lock()
	defer g.mu.Unlock()
	if err == nil {
		f.data = copySnapshot(data)
	}
	f.err = err
	g.observe("finished")
	delete(g.pending, f.key)
	// A short failure cooldown bounds retry multiplication, without stale data.
	if f.generation == g.generation && !errors.Is(err, context.Canceled) {
		if len(g.cached) >= MaxCachedScopes {
			for key := range g.cached {
				delete(g.cached, key)
				break
			}
		}
		f.expires = g.now().Add(TTL)
		g.cached[f.key] = f
	}
	close(f.done)
}

func copySnapshot(data Snapshot) Snapshot {
	if data == nil {
		return nil
	}
	result := make(Snapshot, len(data))
	for key, participants := range data {
		result[key] = append(participants[:0:0], participants...)
	}
	return result
}
