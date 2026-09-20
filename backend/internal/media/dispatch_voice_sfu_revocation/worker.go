package dispatchvoicesfurevocation

import (
	"context"
	"time"
)

const (
	dispatchBatchLimit = 100
	dispatchTimeout    = 5 * time.Second
)

type Dispatcher interface {
	Dispatch(context.Context, int) (Result, error)
}

func DispatchPending(parent context.Context, dispatcher Dispatcher) (Result, error) {
	bounded, cancel := context.WithTimeout(parent, dispatchTimeout)
	defer cancel()
	return dispatcher.Dispatch(bounded, dispatchBatchLimit)
}
