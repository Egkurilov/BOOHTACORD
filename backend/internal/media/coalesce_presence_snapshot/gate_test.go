package coalescepresencesnapshot

import (
	"context"
	"sync"
	"sync/atomic"
	"testing"
	"time"
	presence "voice-platform/backend/internal/media/snapshot_livekit_presence"
)

type sourceFunc func(context.Context, []string) (map[string][]presence.ConnectedLease, error)

func (f sourceFunc) SnapshotRooms(ctx context.Context, ids []string) (map[string][]presence.ConnectedLease, error) {
	return f(ctx, ids)
}

func TestSingleFlightSharesFetchWithoutCallerCancellation(t *testing.T) {
	var calls atomic.Int32
	started, release := make(chan struct{}), make(chan struct{})
	g := New(sourceFunc(func(ctx context.Context, ids []string) (map[string][]presence.ConnectedLease, error) {
		if calls.Add(1) == 1 {
			close(started)
		}
		select {
		case <-release:
			return map[string][]presence.ConnectedLease{"room": {{LeaseID: "lease"}}}, nil
		case <-ctx.Done():
			return nil, ctx.Err()
		}
	}))
	ctx, cancel := context.WithCancel(context.Background())
	first := make(chan error, 1)
	go func() { _, err := g.SnapshotRooms(ctx, []string{"room"}); first <- err }()
	<-started
	joined := make(chan error, 1)
	go func() { _, err := g.SnapshotRooms(context.Background(), []string{"room"}); joined <- err }()
	for {
		g.mu.Lock()
		_, key := canonicalScope([]string{"room"})
		waiters := g.pending[key].waiters
		g.mu.Unlock()
		if waiters == 2 {
			break
		}
		time.Sleep(time.Millisecond)
	}
	cancel()
	if <-first != context.Canceled {
		t.Fatal("caller cancellation lost")
	}
	var group sync.WaitGroup
	for range 100 {
		group.Add(1)
		go func() {
			defer group.Done()
			result, err := g.SnapshotRooms(context.Background(), []string{"room"})
			if err != nil || len(result["room"]) != 1 {
				t.Error("shared result lost")
			}
		}()
	}
	close(release)
	group.Wait()
	if err := <-joined; err != nil {
		t.Fatal(err)
	}
	if calls.Load() != 1 {
		t.Fatal("fan-out not coalesced")
	}
}

func TestSnapshotCopyExpiryAndFailureNeverReturnStale(t *testing.T) {
	now := time.Now()
	calls, failed := 0, false
	g := New(sourceFunc(func(context.Context, []string) (map[string][]presence.ConnectedLease, error) {
		calls++
		if failed {
			return nil, presence.ErrUnavailable
		}
		return map[string][]presence.ConnectedLease{"room": {{LeaseID: "lease"}}}, nil
	}))
	g.now = func() time.Time { return now }
	first, _ := g.SnapshotRooms(context.Background(), []string{"room"})
	first["room"][0].LeaseID = "changed"
	second, _ := g.SnapshotRooms(context.Background(), []string{"room"})
	if second["room"][0].LeaseID != "lease" || calls != 1 {
		t.Fatal("cached result mutated")
	}
	now = now.Add(TTL + time.Nanosecond)
	failed = true
	result, err := g.SnapshotRooms(context.Background(), []string{"room"})
	if err == nil || result != nil {
		t.Fatal("stale cache concealed SFU error")
	}
	failed = false
	now = now.Add(TTL + time.Nanosecond)
	_, _ = g.SnapshotRooms(context.Background(), []string{"room"})
	if calls != 3 {
		t.Fatal("failure was cached")
	}
}
