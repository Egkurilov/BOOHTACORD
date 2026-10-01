// Package lifecycle coordinates resource cleanup and bounded HTTP shutdown.
package lifecycle

import (
	"context"
	"errors"
	"net/http"
	"time"
)

type Stop func(context.Context) error
type Stack struct{ stops []Stop }

func (stack *Stack) Add(stop Stop) { stack.stops = append(stack.stops, stop) }
func (stack *Stack) Close(ctx context.Context) error {
	stops := stack.stops
	stack.stops = nil
	var failures []error
	for index := len(stops) - 1; index >= 0; index-- {
		failures = append(failures, stops[index](ctx))
	}
	return errors.Join(failures...)
}

func Wait(ctx context.Context, stop func()) error {
	done := make(chan struct{})
	go func() { stop(); close(done) }()
	select {
	case <-done:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}

type Server interface {
	ListenAndServe() error
	Shutdown(context.Context) error
	Close() error
}

func Serve(ctx context.Context, server Server) error {
	result := make(chan error, 1)
	go func() { result <- server.ListenAndServe() }()
	select {
	case err := <-result:
		if errors.Is(err, http.ErrServerClosed) {
			return nil
		}
		return err
	case <-ctx.Done():
		shutdown, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := server.Shutdown(shutdown); err != nil {
			return errors.Join(err, server.Close())
		}
		return nil
	}
}
