package reserveuploadspace

import (
	"context"
	"errors"
	"sync"
	"testing"
)

func TestConfirmRejectsReservationAfterAvailableSpaceDrops(t *testing.T) {
	space := &sequenceSpace{snapshots: []Snapshot{
		{AvailableBytes: MinimumFreeBytes + MaxAttachmentBytes, TotalBytes: 10 * gibibyte},
		{AvailableBytes: MinimumFreeBytes + MaxAttachmentBytes - 1, TotalBytes: 10 * gibibyte},
	}}
	manager, err := New(space)
	if err != nil {
		t.Fatal(err)
	}
	reservation, err := manager.Reserve(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	defer reservation.Release()
	if err := manager.Confirm(context.Background()); !errors.Is(err, ErrInsufficientStorage) {
		t.Fatalf("error = %v", err)
	}
	if manager.ReservedBytes() != MaxAttachmentBytes {
		t.Fatalf("reserved bytes = %d", manager.ReservedBytes())
	}
}

type sequenceSpace struct {
	mu        sync.Mutex
	snapshots []Snapshot
	index     int
}

func (space *sequenceSpace) Snapshot(context.Context) (Snapshot, error) {
	space.mu.Lock()
	defer space.mu.Unlock()
	result := space.snapshots[space.index]
	if space.index < len(space.snapshots)-1 {
		space.index++
	}
	return result, nil
}
