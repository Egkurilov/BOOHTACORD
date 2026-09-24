package cleanupunattachedattachments

import (
	"context"
	"errors"
	"testing"
	"time"
)

func TestRunRetriesClaimedRowsAndKeepsFailuresForNextRun(t *testing.T) {
	now := time.Date(2026, 9, 24, 12, 0, 0, 0, time.UTC)
	store := &fakeStore{claimed: []Candidate{{ID: "first", Key: "key-1"}, {ID: "second", Key: "key-2"}}}
	files := &fakeFiles{failKey: "key-1"}
	result, err := New(store, files).Run(context.Background(), now, 2)
	if !errors.Is(err, ErrPartialCleanup) || result.Claimed != 2 || result.Removed != 1 || result.Failed != 1 {
		t.Fatalf("result = %+v, error = %v", result, err)
	}
	if len(store.finalized) != 1 || store.finalized[0] != "second" || store.cutoff != now.Add(-Retention) || store.limit != 2 {
		t.Fatalf("finalized = %v, cutoff = %v, limit = %d", store.finalized, store.cutoff, store.limit)
	}
	if store.audited != result {
		t.Fatalf("audit = %+v, result = %+v", store.audited, result)
	}
	files.failKey = ""
	store.claimed = []Candidate{{ID: "first", Key: "key-1"}}
	result, err = New(store, files).Run(context.Background(), now, 2)
	if err != nil || result.Removed != 1 || len(store.finalized) != 2 {
		t.Fatalf("retry result = %+v, finalized = %v, error = %v", result, store.finalized, err)
	}
}

func TestRunRejectsUnboundedRequests(t *testing.T) {
	service := New(&fakeStore{}, &fakeFiles{})
	for _, limit := range []int{0, MaxBatch + 1} {
		if _, err := service.Run(context.Background(), time.Now(), limit); !errors.Is(err, ErrInvalidRun) {
			t.Fatalf("limit %d error = %v", limit, err)
		}
	}
	if _, err := service.Run(context.Background(), time.Time{}, 1); !errors.Is(err, ErrInvalidRun) {
		t.Fatalf("zero time error = %v", err)
	}
}

func TestRunRetriesWhenMetadataFinalizationFailsAfterUnlink(t *testing.T) {
	store := &fakeStore{claimed: []Candidate{{ID: "claimed", Key: "key"}}, finalizeErr: errors.New("database failure")}
	files := &fakeFiles{}
	service := New(store, files)
	result, err := service.Run(context.Background(), time.Now(), 1)
	if !errors.Is(err, ErrPartialCleanup) || result.Failed != 1 || result.Removed != 0 {
		t.Fatalf("first result = %+v, error = %v", result, err)
	}
	store.finalizeErr = nil
	result, err = service.Run(context.Background(), time.Now(), 1)
	if err != nil || result.Removed != 1 || len(files.removed) != 2 {
		t.Fatalf("retry result = %+v, file calls = %v, error = %v", result, files.removed, err)
	}
}

type fakeStore struct {
	claimed     []Candidate
	cutoff      time.Time
	limit       int
	finalized   []string
	finalizeErr error
	audited     Result
	exists      bool
}

func (s *fakeStore) Claim(_ context.Context, cutoff time.Time, limit int) ([]Candidate, error) {
	s.cutoff, s.limit = cutoff, limit
	return s.claimed, nil
}
func (s *fakeStore) Finalize(_ context.Context, id string) error {
	s.finalized = append(s.finalized, id)
	return s.finalizeErr
}
func (s *fakeStore) Exists(_ context.Context, _ string) (bool, error) { return s.exists, nil }
func (s *fakeStore) Audit(_ context.Context, result Result) error     { s.audited = result; return nil }

type fakeFiles struct {
	failKey string
	old     bool
	removed []string
}

func (f *fakeFiles) Remove(key string) error {
	if key == f.failKey {
		return errors.New("filesystem failure")
	}
	f.removed = append(f.removed, key)
	return nil
}
func (f *fakeFiles) OldRegular(_ string, _ time.Time) (bool, error) { return f.old, nil }
