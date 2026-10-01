package periodic

import (
	"context"
	"errors"
	"testing"
	"time"
)

func TestStopCancelsAndWaitsForActiveWork(t *testing.T) {
	started, exited := make(chan struct{}), make(chan struct{})
	worker := Start(context.Background(), time.Hour, func(ctx context.Context) {
		close(started)
		<-ctx.Done()
		close(exited)
	})
	<-started
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	if err := worker.Stop(ctx); err != nil {
		t.Fatal(err)
	}
	select {
	case <-exited:
	default:
		t.Fatal("stop returned before work ended")
	}
	if err := worker.Stop(ctx); err != nil {
		t.Fatal("stop must be idempotent", err)
	}
}

func TestStopDeadlineBoundsUncooperativeWork(t *testing.T) {
	started, release := make(chan struct{}), make(chan struct{})
	worker := Start(context.Background(), time.Hour, func(context.Context) { close(started); <-release })
	<-started
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if err := worker.Stop(ctx); !errors.Is(err, context.Canceled) {
		t.Fatalf("got %v", err)
	}
	close(release)
	if err := worker.Stop(t.Context()); err != nil {
		t.Fatal(err)
	}
}
