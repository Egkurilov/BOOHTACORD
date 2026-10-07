package exercise_actor

import (
	"context"
	"errors"
)

func (a *Actor) reserve(cleanup bool) error {
	for {
		current := a.Budget.Load()
		if !cleanup && current >= int64(a.Manifest.MaxRequests) {
			return errors.New("request budget exhausted")
		}
		if a.Budget.CompareAndSwap(current, current+1) {
			return nil
		}
	}
}
func (a *Actor) connect(ctx context.Context, resume bool) error {
	if err := a.reserve(false); err != nil {
		return err
	}
	return a.Socket.Connect(ctx, a.Client, a.Manifest.Origin, resume)
}
