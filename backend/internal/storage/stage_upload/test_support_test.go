package stageupload

import (
	"context"
	"io"
	"os"
	"sync"
	"testing"

	reserveuploadspace "voice-platform/backend/internal/storage/reserve_upload_space"
	writeupload "voice-platform/backend/internal/storage/write_upload"
)

const gibibyte int64 = 1024 * 1024 * 1024

func newStager(t *testing.T, manager *reserveuploadspace.Manager, directory string) Service {
	t.Helper()
	writer, err := writeupload.New(directory)
	if err != nil {
		t.Fatal(err)
	}
	return New(manager, writer)
}

func newManager(t *testing.T, space reserveuploadspace.Space) *reserveuploadspace.Manager {
	t.Helper()
	manager, err := reserveuploadspace.New(space)
	if err != nil {
		t.Fatal(err)
	}
	return manager
}

func spaceAtReserve() reserveuploadspace.Snapshot {
	return reserveuploadspace.Snapshot{AvailableBytes: reserveuploadspace.MinimumFreeBytes + reserveuploadspace.MaxAttachmentBytes, TotalBytes: 10 * gibibyte}
}

func spaceBelowReserve() reserveuploadspace.Snapshot {
	return reserveuploadspace.Snapshot{AvailableBytes: reserveuploadspace.MinimumFreeBytes + reserveuploadspace.MaxAttachmentBytes - 1, TotalBytes: 10 * gibibyte}
}

func assertDirectoryEmpty(t *testing.T, directory string) {
	t.Helper()
	entries, err := os.ReadDir(directory)
	if err != nil || len(entries) != 0 {
		t.Fatalf("entries = %#v, error = %v", entries, err)
	}
}

type sequenceSpace struct {
	mu        sync.Mutex
	snapshots []reserveuploadspace.Snapshot
	index     int
}

func (space *sequenceSpace) Snapshot(context.Context) (reserveuploadspace.Snapshot, error) {
	space.mu.Lock()
	defer space.mu.Unlock()
	result := space.snapshots[space.index]
	if space.index < len(space.snapshots)-1 {
		space.index++
	}
	return result, nil
}

type twoReadSource struct{ reads int }

func (source *twoReadSource) Read(buffer []byte) (int, error) {
	if source.reads == 2 {
		return 0, io.EOF
	}
	source.reads++
	buffer[0] = 'x'
	return 1, nil
}
