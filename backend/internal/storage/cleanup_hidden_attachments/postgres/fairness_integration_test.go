package cleanuphiddenattachmentspostgres

import (
	"context"
	"testing"
	"time"
)

func TestHiddenClaimPrioritizesUnattemptedOverExpiredRetry(t *testing.T) {
	f := newFixture(t)
	ctx := context.Background()
	repo := New(f.pool)
	first, err := repo.Claim(ctx, time.Now().UTC(), 1)
	if err != nil || len(first) != 1 {
		t.Fatalf("first=%+v err=%v", first, err)
	}
	if _, err := f.pool.Exec(ctx, `UPDATE attachments SET hidden_at=now()-interval '2 days', hidden_cleanup_claimed_at=now()-interval '10 minutes' WHERE id=$1`, first[0].ID); err != nil {
		t.Fatal(err)
	}
	second, err := repo.Claim(ctx, time.Now().UTC(), 1)
	if err != nil || len(second) != 1 {
		t.Fatalf("second=%+v err=%v", second, err)
	}
	if second[0].ID == first[0].ID {
		t.Fatal("expired failed row starved an unattempted attachment")
	}
	third, err := repo.Claim(ctx, time.Now().UTC(), 1)
	if err != nil || len(third) != 1 || third[0].ID != first[0].ID {
		t.Fatalf("expired retry was lost: third=%+v err=%v", third, err)
	}
}
