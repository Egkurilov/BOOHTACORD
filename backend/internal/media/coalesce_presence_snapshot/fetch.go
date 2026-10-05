package coalescepresencesnapshot

import (
	"context"
	"time"
)

func (g *Gate) fetch(f *flight, ids []string) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	data, err := g.source.SnapshotRooms(ctx, ids)
	g.mu.Lock()
	defer g.mu.Unlock()
	f.data, f.err = copySnapshot(data), err
	g.pending = nil
	if err == nil {
		f.expires = g.now().Add(TTL)
		g.cached = f
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
