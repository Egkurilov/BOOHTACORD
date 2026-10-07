package observedependencies

import (
	"context"
	"errors"
	"github.com/prometheus/client_golang/prometheus"
	dto "github.com/prometheus/client_model/go"
	"testing"
	"time"
	incident "voice-platform/backend/internal/observability/observe_incidents"
	reserve "voice-platform/backend/internal/storage/reserve_upload_space"
)

type fakeSFU struct{ deadline bool }

func (f *fakeSFU) Ping(ctx context.Context) error {
	_, f.deadline = ctx.Deadline()
	return errors.New("private-room")
}

type fakeSpace struct{ deadline bool }

func (f *fakeSpace) Snapshot(ctx context.Context) (reserve.Snapshot, error) {
	_, f.deadline = ctx.Deadline()
	return reserve.Snapshot{AvailableBytes: 2, TotalBytes: 1}, nil
}
func TestProbesBoundedAndInvalidSnapshotsFail(t *testing.T) {
	old := incident.Default
	incident.Default = incident.New()
	defer func() { incident.Default = old }()
	sfu := &fakeSFU{}
	space := &fakeSpace{}
	started := time.Now()
	Attempt(context.Background(), sfu, space)
	if !sfu.deadline || !space.deadline || time.Since(started) > time.Second {
		t.Fatal("unbounded")
	}
	c := make(chan prometheus.Metric, 64)
	incident.Default.Collect(c)
	close(c)
	failures := 0
	for sample := range c {
		m := &dto.Metric{}
		_ = sample.Write(m)
		if m.Counter != nil && m.Counter.GetValue() == 1 {
			failures++
		}
	}
	if failures != 2 {
		t.Fatal(failures)
	}
}
