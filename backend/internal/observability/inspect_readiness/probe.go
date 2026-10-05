package inspectreadiness

import (
	"context"
	"sync/atomic"
	"time"
)

type boundedProbe struct{ busy atomic.Bool }

func (p *boundedProbe) run(parent context.Context, read func(context.Context) Probe) Probe {
	if !p.busy.CompareAndSwap(false, true) {
		return Probe{Status: "unknown", Reason: "busy"}
	}
	ctx, cancel := context.WithTimeout(parent, 400*time.Millisecond)
	defer cancel()
	done := make(chan Probe, 1)
	go func() { defer p.busy.Store(false); done <- read(ctx) }()
	select {
	case result := <-done:
		now := time.Now().UTC()
		result.SampledAt = &now
		return result
	case <-ctx.Done():
		return Probe{Status: "unknown", Reason: "timeout"}
	}
}
