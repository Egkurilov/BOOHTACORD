package coalescepresencesnapshot

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"sync/atomic"
	"testing"
)

func TestDistinctScopeBudgetRejectsWithoutQueueAndCancelsAbandonedFetches(t *testing.T) {
	started, ended := make(chan struct{}, MaxActiveScopes), make(chan struct{}, MaxActiveScopes)
	var calls atomic.Int32
	gate := New(sourceFunc(func(ctx context.Context, _ []string) (Snapshot, error) {
		calls.Add(1)
		started <- struct{}{}
		<-ctx.Done()
		ended <- struct{}{}
		return nil, ctx.Err()
	}))
	ctx, cancel := context.WithCancel(context.Background())
	var group sync.WaitGroup
	for index := range MaxActiveScopes {
		group.Add(1)
		go func() { defer group.Done(); _, _ = gate.SnapshotRooms(ctx, []string{fmt.Sprint(index)}) }()
	}
	for range MaxActiveScopes {
		<-started
	}
	if data, err := gate.SnapshotRooms(ctx, []string{"another"}); !errors.Is(err, ErrOverloaded) || data != nil {
		t.Fatalf("budget result=%v err=%v", data, err)
	}
	if calls.Load() != MaxActiveScopes {
		t.Fatalf("source calls=%d", calls.Load())
	}
	cancel()
	group.Wait()
	for range MaxActiveScopes {
		<-ended
	}
}

func TestWebhookInvalidationDiscardsCompletedAndInFlightCache(t *testing.T) {
	var calls atomic.Int32
	started, release := make(chan struct{}), make(chan struct{})
	gate := New(sourceFunc(func(context.Context, []string) (Snapshot, error) {
		if calls.Add(1) == 1 {
			close(started)
			<-release
		}
		return Snapshot{}, nil
	}))
	result := make(chan error, 1)
	go func() { _, err := gate.SnapshotRooms(context.Background(), []string{"room"}); result <- err }()
	<-started
	gate.Invalidate()
	close(release)
	if err := <-result; err != nil {
		t.Fatal(err)
	}
	_, _ = gate.SnapshotRooms(context.Background(), []string{"room"})
	gate.Invalidate()
	_, _ = gate.SnapshotRooms(context.Background(), []string{"room"})
	if calls.Load() != 3 {
		t.Fatalf("invalidated cache retained; calls=%d", calls.Load())
	}
}

func TestFailureCooldownNeverRetainsPartialOrStalePayload(t *testing.T) {
	var calls atomic.Int32
	gate := New(sourceFunc(func(context.Context, []string) (Snapshot, error) {
		calls.Add(1)
		return Snapshot{"secret": nil}, errors.New("upstream down")
	}))
	for range 100 {
		data, err := gate.SnapshotRooms(context.Background(), []string{"room"})
		if data != nil || err == nil {
			t.Fatalf("failure disclosed result=%v err=%v", data, err)
		}
	}
	if calls.Load() != 1 {
		t.Fatalf("failure storm=%d calls", calls.Load())
	}
}
