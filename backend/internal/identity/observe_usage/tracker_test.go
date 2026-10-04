package observeusage

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"
)

type fakeStore struct {
	mu       sync.Mutex
	writes   []time.Time
	err      error
	snapshot Snapshot
}

func (s *fakeStore) Record(_ context.Context, _ string, at time.Time) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.writes = append(s.writes, at)
	return s.err
}
func (s *fakeStore) Snapshot(context.Context, time.Time) (Snapshot, error) { return s.snapshot, s.err }

func TestTrackerDeduplicatesDailyAndUsesMoscowMidnight(t *testing.T) {
	now := time.Date(2026, 10, 4, 20, 59, 0, 0, time.UTC)
	store := &fakeStore{}
	tracker := NewTracker(store, func() time.Time { return now })
	tracker.Record(context.Background(), "account-a")
	tracker.Record(context.Background(), "account-a")
	tracker.Record(context.Background(), "account-b")
	now = now.Add(2 * time.Minute)
	tracker.Record(context.Background(), "account-a")
	if len(store.writes) != 3 || Day(store.writes[2]).Format("2006-01-02") != "2026-10-05" {
		t.Fatalf("daily writes = %v", store.writes)
	}
}

func TestFailedWriteRetriesWithoutPoisoningDailyCache(t *testing.T) {
	store := &fakeStore{err: errors.New("unavailable")}
	tracker := NewTracker(store, time.Now)
	tracker.Record(context.Background(), "account")
	store.err = nil
	tracker.Record(context.Background(), "account")
	tracker.Record(context.Background(), "account")
	if len(store.writes) != 2 || tracker.failures.Load() != 1 {
		t.Fatal("write was lost or repeated")
	}
}

func TestCacheIsBoundedAndSafeForConcurrentRequests(t *testing.T) {
	tracker := NewTracker(&fakeStore{}, time.Now)
	var tasks sync.WaitGroup
	for i := 0; i < 30; i++ {
		tasks.Add(1)
		go func() { defer tasks.Done(); tracker.Record(context.Background(), "same-account") }()
	}
	tasks.Wait()
	if len(tracker.seen) != 1 {
		t.Fatal("concurrent cache is inconsistent")
	}
	for i := 0; i < cacheLimit+1; i++ {
		tracker.Record(context.Background(), time.Unix(int64(i), 0).String())
	}
	if len(tracker.seen) > cacheLimit {
		t.Fatal("unbounded activity cache")
	}
}
