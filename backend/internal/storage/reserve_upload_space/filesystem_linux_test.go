//go:build linux

package reserveuploadspace

import (
	"context"
	"errors"
	"testing"
)

func TestFilesystemSnapshotReportsBoundedByteCounts(t *testing.T) {
	filesystem, err := NewFilesystem(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	snapshot, err := filesystem.Snapshot(context.Background())
	if err != nil || snapshot.TotalBytes <= 0 || snapshot.AvailableBytes < 0 || snapshot.AvailableBytes > snapshot.TotalBytes {
		t.Fatalf("snapshot = %#v, error = %v", snapshot, err)
	}
}

func TestNewFilesystemRejectsEmptyPath(t *testing.T) {
	_, err := NewFilesystem("")
	if !errors.Is(err, ErrInvalidSpace) {
		t.Fatalf("error = %v", err)
	}
}
