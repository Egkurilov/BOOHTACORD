package watchconnectedparticipants

import (
	"context"
	"math/rand/v2"
	"net/http"
	"time"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
)

// One retry shares the original five-second deadline. Initial requests and
// the SFU gate never retry independently; clients retain their bounded backoff.
func loadRefresh(ctx context.Context, lister Lister, actorID string) (roster.Result, error) {
	value, err := lister.List(ctx, actorID)
	if err == nil || ctx.Err() != nil || roster.FailureStatus(err) != http.StatusServiceUnavailable {
		return value, err
	}
	timer := time.NewTimer(300*time.Millisecond + time.Duration(rand.IntN(100))*time.Millisecond)
	defer timer.Stop()
	select {
	case <-ctx.Done():
		return roster.Result{}, ctx.Err()
	case <-timer.C:
		return lister.List(ctx, actorID)
	}
}

// Spread reconciliation without raising the existing five-second ceiling.
func reconciliationPeriod(interval time.Duration) time.Duration {
	if interval < time.Second {
		return interval
	}
	return interval - time.Duration(rand.IntN(251))*time.Millisecond
}
