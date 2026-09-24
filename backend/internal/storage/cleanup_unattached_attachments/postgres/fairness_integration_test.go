package cleanupunattachedattachmentspostgres

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	cleanup "voice-platform/backend/internal/storage/cleanup_unattached_attachments"
)

func assertFairBatch(t *testing.T, ctx context.Context, pool *pgxpool.Pool, repo Repository, now time.Time) {
	t.Helper()
	unattached := map[string]bool{}
	for index := 0; index < 20; index++ {
		id := uuid.New()
		unattached[id.String()] = true
		_, err := pool.Exec(ctx, `INSERT INTO attachments (id, storage_key, state, created_at)
VALUES ($1,$2,'UNATTACHED',$3)`, id, uuid.New(), now.Add(-25*time.Hour))
		if err != nil {
			t.Fatal(err)
		}
	}
	for index := 0; index < 120; index++ {
		_, err := pool.Exec(ctx, `INSERT INTO attachments (id, storage_key, state, created_at, unattached_cleanup_retry_after)
VALUES ($1,$2,'DELETING',$3,$4)`, uuid.New(), uuid.New(), now.Add(-48*time.Hour), now.Add(-time.Hour))
		if err != nil {
			t.Fatal(err)
		}
	}
	recentRetry := uuid.New()
	_, err := pool.Exec(ctx, `INSERT INTO attachments (id, storage_key, state, created_at, unattached_cleanup_retry_after)
VALUES ($1,$2,'DELETING',$3,$4)`, recentRetry, uuid.New(), now, now.Add(-2*time.Hour))
	if err != nil {
		t.Fatal(err)
	}
	first, err := repo.Claim(ctx, now.Add(-24*time.Hour), 10)
	if err != nil {
		t.Fatal(err)
	}
	assertLaneMix(t, first, unattached, 5)
	firstIDs := map[string]bool{}
	for _, candidate := range first {
		firstIDs[candidate.ID] = true
	}
	if !firstIDs[recentRetry.String()] {
		t.Fatal("due DELETING row created less than 24h ago was not retried")
	}
	second, err := repo.Claim(ctx, now.Add(-24*time.Hour), 10)
	if err != nil {
		t.Fatal(err)
	}
	assertLaneMix(t, second, unattached, 5)
	for _, candidate := range second {
		if firstIDs[candidate.ID] {
			t.Fatal("cooling-down failure claimed again on the next run")
		}
	}
	one, err := repo.Claim(ctx, now.Add(-24*time.Hour), 1)
	if err != nil || len(one) != 1 {
		t.Fatalf("first single-item claim = %+v, error = %v", one, err)
	}
	two, err := repo.Claim(ctx, now.Add(-24*time.Hour), 1)
	if err != nil || len(two) != 1 {
		t.Fatalf("second single-item claim = %+v, error = %v", two, err)
	}
	if unattached[one[0].ID] == unattached[two[0].ID] {
		t.Fatalf("single-item runs failed to alternate lanes: %+v, %+v", one, two)
	}
}

func assertLaneMix(t *testing.T, batch []cleanup.Candidate, unattached map[string]bool, expectedFresh int) {
	t.Helper()
	if len(batch) != 10 {
		t.Fatalf("batch length = %d, want 10", len(batch))
	}
	fresh := 0
	for _, candidate := range batch {
		if unattached[candidate.ID] {
			fresh++
		}
	}
	if fresh != expectedFresh {
		t.Fatalf("fresh count = %d, want %d", fresh, expectedFresh)
	}
}
