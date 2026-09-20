package reserveuploadspace

import (
	"context"
	"errors"
	"sync"
	"testing"
)

const gibibyte int64 = 1024 * 1024 * 1024

func TestReserveAdmitsExactTwoGiBReserveBoundary(t *testing.T) {
	manager, err := New(fakeSpace{snapshot: Snapshot{
		AvailableBytes: MinimumFreeBytes + MaxAttachmentBytes,
		TotalBytes:     10 * gibibyte,
	}})
	if err != nil {
		t.Fatal(err)
	}
	reservation, err := manager.Reserve(context.Background())
	if err != nil || reservation == nil {
		t.Fatalf("reservation = %#v, error = %v", reservation, err)
	}
	_, err = manager.Reserve(context.Background())
	if !errors.Is(err, ErrInsufficientStorage) {
		t.Fatalf("error = %v", err)
	}
}
func TestReserveUsesTenPercentWhenItExceedsTwoGiB(t *testing.T) {
	manager, err := New(fakeSpace{snapshot: Snapshot{
		AvailableBytes: 4*gibibyte + MaxAttachmentBytes,
		TotalBytes:     40 * gibibyte,
	}})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := manager.Reserve(context.Background()); err != nil {
		t.Fatal(err)
	}
	if _, err := manager.Reserve(context.Background()); !errors.Is(err, ErrInsufficientStorage) {
		t.Fatalf("error = %v", err)
	}
}
func TestReservationReleaseIsIdempotent(t *testing.T) {
	manager, err := New(fakeSpace{snapshot: Snapshot{
		AvailableBytes: MinimumFreeBytes + MaxAttachmentBytes,
		TotalBytes:     10 * gibibyte,
	}})
	if err != nil {
		t.Fatal(err)
	}
	reservation, err := manager.Reserve(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	reservation.Release()
	reservation.Release()
	if manager.ReservedBytes() != 0 {
		t.Fatalf("reserved bytes = %d", manager.ReservedBytes())
	}
	if _, err := manager.Reserve(context.Background()); err != nil {
		t.Fatal(err)
	}
}
func TestReserveDoesNotOverAdmitConcurrentUploads(t *testing.T) {
	manager, err := New(fakeSpace{snapshot: Snapshot{
		AvailableBytes: MinimumFreeBytes + 3*MaxAttachmentBytes,
		TotalBytes:     10 * gibibyte,
	}})
	if err != nil {
		t.Fatal(err)
	}
	var admitted int
	var lock sync.Mutex
	var group sync.WaitGroup
	for range 8 {
		group.Add(1)
		go func() {
			defer group.Done()
			if _, err := manager.Reserve(context.Background()); err == nil {
				lock.Lock()
				admitted++
				lock.Unlock()
			}
		}()
	}
	group.Wait()
	if admitted != 3 || manager.ReservedBytes() != 3*MaxAttachmentBytes {
		t.Fatalf("admitted = %d, reserved = %d", admitted, manager.ReservedBytes())
	}
}

type fakeSpace struct {
	snapshot Snapshot
	err      error
}

func (space fakeSpace) Snapshot(context.Context) (Snapshot, error) {
	return space.snapshot, space.err
}
