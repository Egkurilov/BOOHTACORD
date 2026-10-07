package exercise_actor

import (
	"context"
	"sync/atomic"
	"testing"
	"time"
	"voice-platform/backend/internal/load/record_results"
)

func TestReplayAndResyncConsumeBeforeReady(t *testing.T) {
	f := newFixture(t)
	defer f.close()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	r := record_results.New()
	a := New(f.manifest, 0, r, &atomic.Int64{})
	defer a.Socket.Close()
	if err := a.Start(ctx); err != nil {
		t.Fatal(err)
	}
	if err := a.Message(ctx, []*Actor{a}, nil); err != nil {
		t.Fatal(err)
	}
	if err := a.Reconnect(ctx); err != nil {
		t.Fatal(err)
	}
	if r.Snapshot()["replay"].Count == 0 {
		t.Fatal("replayed durable hint absent")
	}
	f.forceResync = true
	if err := a.Reconnect(ctx); err != nil {
		t.Fatal(err)
	}
	if !a.Socket.Resync() || r.Snapshot()["resync"].Count != 1 || r.Snapshot()["history"].Count != 2 {
		t.Fatal("resync did not rebuild protected state before ready")
	}
}
