package coalescepresencesnapshot

import (
	"context"
	"errors"
	"sync"
	"time"
	presence "voice-platform/backend/internal/media/snapshot_livekit_presence"
)

const TTL = 250 * time.Millisecond
const MaxActiveScopes = 4
const MaxCachedScopes = 16

var ErrOverloaded = errors.New("voice presence refresh budget exhausted")

type Snapshot = map[string][]presence.ConnectedLease
type Source interface {
	SnapshotRooms(context.Context, []string) (Snapshot, error)
}
type flight struct {
	key        string
	done       chan struct{}
	data       Snapshot
	err        error
	expires    time.Time
	cancel     context.CancelFunc
	waiters    int
	generation uint64
}

// Only volatile SFU observations are shared, never authorized user rosters.
type Gate struct {
	mu              sync.Mutex
	source          Source
	observer        Observer
	pending, cached map[string]*flight
	now             func() time.Time
	generation      uint64
}

func New(source Source, observers ...Observer) *Gate {
	gate := &Gate{source: source, now: time.Now, pending: make(map[string]*flight), cached: make(map[string]*flight)}
	if len(observers) > 0 {
		gate.observer = observers[0]
	}
	return gate
}
