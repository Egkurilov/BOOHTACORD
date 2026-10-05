package inspectreadiness

import (
	"context"
	"errors"
	"testing"
	"time"
	reserve "voice-platform/backend/internal/storage/reserve_upload_space"
)

type databaseStub struct{ err error }

func (d databaseStub) Inspect(context.Context) (int64, error) { return 3, d.err }

type sfuStub struct{ err error }

func (s sfuStub) Ping(context.Context) error { return s.err }

type storageStub struct {
	err       error
	available int64
}

func (s storageStub) Snapshot(context.Context) (reserve.Snapshot, error) {
	return reserve.Snapshot{AvailableBytes: s.available, TotalBytes: 10 << 30}, s.err
}
func TestFailedDependenciesNeverReportReadyOrInventNumbers(t *testing.T) {
	failure := errors.New("private error with token")
	result := New(databaseStub{failure}, sfuStub{failure}, storageStub{err: failure}, func() int64 { return 0 }).Inspect(context.Background())
	if result.Status == "ready" || result.Database.PendingRevocations != nil || result.Storage.AvailableBytes != nil || result.SFU.Status == "ready" {
		t.Fatalf("unsafe result=%+v", result)
	}
}
func TestObservedHeadroomAndPendingAreSeparate(t *testing.T) {
	result := New(databaseStub{}, sfuStub{}, storageStub{available: 5 << 30}, func() int64 { return 25000000 }).Inspect(context.Background())
	if result.Status != "ready" || result.Database.PendingRevocations == nil || *result.Database.PendingRevocations != 3 || result.Storage.HeadroomBytes == nil || *result.Storage.HeadroomBytes != 3*(1<<30)-25000000 {
		t.Fatalf("result=%+v", result)
	}
	result = New(databaseStub{}, sfuStub{}, storageStub{available: 1 << 30}, func() int64 { return 0 }).Inspect(context.Background())
	if result.Status == "ready" || result.Storage.Reason != "insufficient_space" {
		t.Fatalf("low space=%+v", result)
	}
}
func TestUncooperativeProbeTimesOutWithoutUnboundedDuplicateWork(t *testing.T) {
	probe := &boundedProbe{}
	finish := make(chan struct{})
	started := time.Now()
	result := probe.run(context.Background(), func(context.Context) Probe { <-finish; return Probe{Status: "ready"} })
	if time.Since(started) > time.Second || result.Status != "unknown" || result.Reason != "timeout" {
		t.Fatalf("timeout=%+v", result)
	}
	second := probe.run(context.Background(), func(context.Context) Probe { t.Error("duplicated stalled probe"); return Probe{} })
	if second.Reason != "busy" {
		t.Fatalf("second=%+v", second)
	}
	close(finish)
}
