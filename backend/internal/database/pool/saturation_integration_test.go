package pool

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/prometheus/client_golang/prometheus"
	dto "github.com/prometheus/client_model/go"
	"os"
	"testing"
	"time"
	"voice-platform/backend/internal/testsupport/databasecheck"
)

func TestDisposableDatabasePoolSaturation(t *testing.T) {
	primary, legacy := os.Getenv("VOICE_PLATFORM_TEST_DATABASE_URL"), os.Getenv("TEST_DATABASE_URL")
	if primary == "" && legacy == "" {
		t.Skip("disposable database environment absent; native PostgreSQL CI executes saturation")
	}
	guarded, err := databasecheck.Config(primary, legacy)
	if err != nil {
		t.Fatal(err)
	}
	config, err := pgxpool.ParseConfig(primary)
	if err != nil {
		t.Fatal("test pool configuration invalid")
	}
	config.ConnConfig = guarded
	config.MaxConns = 1
	config.MinConns = 0
	m := NewMetrics()
	config.ConnConfig.Tracer = m
	ctx, cancel := context.WithTimeout(t.Context(), 5*time.Second)
	defer cancel()
	database, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		t.Fatal("disposable pool unavailable")
	}
	defer database.Close()
	m.pool = database
	held, err := database.Acquire(ctx)
	if err != nil {
		t.Fatal("disposable connection unavailable")
	}
	defer held.Release()
	if s := database.Stat(); s.AcquiredConns() != 1 || s.MaxConns() != 1 {
		t.Fatal("pool not saturated")
	}
	acquireCtx, stop := context.WithTimeout(ctx, 150*time.Millisecond)
	defer stop()
	result := make(chan error, 1)
	started := time.Now()
	go func() {
		connection, err := database.Acquire(acquireCtx)
		if connection != nil {
			connection.Release()
		}
		result <- err
	}()
	limit := time.Now().Add(time.Second)
	pending := false
	for time.Now().Before(limit) {
		if samplePoolMetric(m.pending).GetGauge().GetValue() == 1 {
			pending = true
			break
		}
		time.Sleep(time.Millisecond)
	}
	if !pending {
		t.Fatal("pending acquisition not observed")
	}
	if err := <-result; !errors.Is(err, context.DeadlineExceeded) {
		t.Fatal("saturated acquire must time out")
	}
	if time.Since(started) < 100*time.Millisecond {
		t.Fatal("acquire wait was not measured")
	}
	if samplePoolMetric(m.pending).GetGauge().GetValue() != 0 || samplePoolMetric(m.acquires.WithLabelValues("timeout")).GetCounter().GetValue() != 1 || samplePoolMetric(m.duration.WithLabelValues("timeout").(prometheus.Metric)).GetHistogram().GetSampleCount() != 1 {
		t.Fatal("timeout outcome/latency missing")
	}
	held.Release()
	released, err := database.Acquire(ctx)
	if err != nil {
		t.Fatal("pool did not recover after release")
	}
	released.Release()
	if samplePoolMetric(m.acquires.WithLabelValues("success")).GetCounter().GetValue() != 2 || database.Stat().AcquiredConns() != 0 || database.Stat().IdleConns() != 1 {
		t.Fatal("recovered pool stats incorrect")
	}
	registry := prometheus.NewRegistry()
	registry.MustRegister(m)
	families, err := registry.Gather()
	if err != nil {
		t.Fatal(err)
	}
	found := false
	for _, family := range families {
		if family.GetName() == "voice_platform_database_pool_max" && family.Metric[0].GetGauge().GetValue() == 1 {
			found = true
		}
	}
	if !found {
		t.Fatal("live pool statistics missing")
	}
}
func samplePoolMetric(metric prometheus.Metric) *dto.Metric {
	sample := &dto.Metric{}
	_ = metric.Write(sample)
	return sample
}
