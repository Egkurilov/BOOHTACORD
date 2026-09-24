package cleanuphiddenattachments

import (
	"context"
	"errors"
	"testing"
	"time"
)

type fakeStore struct {
	items               []Candidate
	finalizeErr         error
	auditErr            error
	finalized, released int
}

func (f *fakeStore) Claim(context.Context, time.Time, int) ([]Candidate, error) { return f.items, nil }
func (f *fakeStore) Finalize(_ context.Context, _ Candidate) error {
	f.finalized++
	return f.finalizeErr
}
func (f *fakeStore) Release(_ context.Context, _ Candidate) error { f.released++; return nil }
func (f *fakeStore) Audit(_ context.Context, _ Result) error      { return f.auditErr }

type fakeFiles struct {
	err     error
	removed int
}

func (f *fakeFiles) Remove(string) error { f.removed++; return f.err }

func TestRunKeepsFailedFileRetryable(t *testing.T) {
	store := &fakeStore{items: []Candidate{{ID: "id", Key: "key", Token: "token"}}}
	files := &fakeFiles{err: errors.New("disk unavailable")}
	result, err := New(store, files).Run(context.Background(), time.Now(), 1)
	if !errors.Is(err, ErrPartialCleanup) || result.Failed != 1 || store.finalized != 0 || store.released != 0 {
		t.Fatalf("result=%+v err=%v store=%+v", result, err, store)
	}
}

func TestRunRetriesAfterFileRemovedButDatabaseFails(t *testing.T) {
	store := &fakeStore{items: []Candidate{{ID: "id", Key: "key", Token: "token"}}, finalizeErr: errors.New("database unavailable")}
	files := &fakeFiles{}
	result, err := New(store, files).Run(context.Background(), time.Now(), 1)
	if !errors.Is(err, ErrPartialCleanup) || result.Failed != 1 || files.removed != 1 || store.finalized != 1 {
		t.Fatalf("result=%+v err=%v store=%+v files=%+v", result, err, store, files)
	}
}

func TestRunRejectsUnboundedBatch(t *testing.T) {
	for _, limit := range []int{0, MaxBatch + 1} {
		if _, err := New(&fakeStore{}, &fakeFiles{}).Run(context.Background(), time.Now(), limit); !errors.Is(err, ErrInvalidRun) {
			t.Fatalf("limit %d: %v", limit, err)
		}
	}
}
