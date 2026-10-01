// Package periodic owns cancellation and completion of one sequential worker.
package periodic

import (
	"context"
	"time"
)

type Worker struct {
	cancel context.CancelFunc
	done   chan struct{}
}

func Start(parent context.Context, interval time.Duration, work func(context.Context)) *Worker {
	ctx, cancel := context.WithCancel(parent)
	worker := &Worker{cancel: cancel, done: make(chan struct{})}
	go func() {
		defer close(worker.done)
		ticker := time.NewTicker(interval)
		defer ticker.Stop()
		for {
			if ctx.Err() != nil {
				return
			}
			work(ctx)
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
			}
		}
	}()
	return worker
}

func (worker *Worker) Stop(ctx context.Context) error {
	worker.cancel()
	select {
	case <-worker.done:
		return nil
	default:
	}
	select {
	case <-worker.done:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}
