package pool

import (
	"context"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"time"
	incident "voice-platform/backend/internal/observability/observe_incidents"
)

type acquireStartKey struct{}

func (m *Metrics) TraceAcquireStart(ctx context.Context, _ *pgxpool.Pool, _ pgxpool.TraceAcquireStartData) context.Context {
	m.pending.Inc()
	return context.WithValue(ctx, acquireStartKey{}, time.Now())
}
func (m *Metrics) TraceAcquireEnd(ctx context.Context, _ *pgxpool.Pool, data pgxpool.TraceAcquireEndData) {
	started, ok := ctx.Value(acquireStartKey{}).(time.Time)
	if !ok {
		return
	}
	m.pending.Dec()
	outcome := incident.Outcome(data.Err)
	m.acquires.WithLabelValues(outcome).Inc()
	m.duration.WithLabelValues(outcome).Observe(time.Since(started).Seconds())
	m.exportAcquire(outcome, time.Since(started))
}

// QueryTracer is required by pgx configuration; no queries or arguments are retained.
func (m *Metrics) TraceQueryStart(ctx context.Context, _ *pgx.Conn, _ pgx.TraceQueryStartData) context.Context {
	return ctx
}
func (m *Metrics) TraceQueryEnd(context.Context, *pgx.Conn, pgx.TraceQueryEndData) {}
