package exercise_actor

import (
	"context"
	"sync/atomic"
	"testing"
	"voice-platform/backend/internal/load/record_results"
)

func TestReconnectCannotDialAfterBudgetExhaustion(t *testing.T) {
	f := newFixture(t)
	defer f.close()
	budget := &atomic.Int64{}
	a := New(f.manifest, 0, record_results.New(), budget)
	budget.Store(int64(f.manifest.MaxRequests))
	if a.Reconnect(context.Background()) == nil {
		t.Fatal("upgrade escaped global request budget")
	}
	if budget.Load() != int64(f.manifest.MaxRequests) || a.Results.Snapshot()["ws_ready"].Count != 0 {
		t.Fatal("budget denial dialled or counted a request")
	}
}
