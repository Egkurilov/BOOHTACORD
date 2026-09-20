package main

import (
	"context"
	"errors"
	"testing"

	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
	reserve "voice-platform/backend/internal/storage/reserve_upload_space"
)

func TestAttachmentFilesystemMetricSourceMapsStorageSnapshot(t *testing.T) {
	space := &fakeAttachmentSpace{snapshot: reserve.Snapshot{AvailableBytes: 7, TotalBytes: 11}}
	snapshot, err := (attachmentFilesystemMetricSource{space: space}).Snapshot(context.Background())
	if err != nil || snapshot != (httpmetrics.AttachmentFilesystemSnapshot{AvailableBytes: 7, TotalBytes: 11}) || !space.called {
		t.Fatalf("snapshot = %#v, error = %v, called = %t", snapshot, err, space.called)
	}
}

func TestAttachmentFilesystemMetricSourceForwardsStorageError(t *testing.T) {
	failure := errors.New("filesystem unavailable")
	space := &fakeAttachmentSpace{err: failure}
	_, err := (attachmentFilesystemMetricSource{space: space}).Snapshot(context.Background())
	if !errors.Is(err, failure) || !space.called {
		t.Fatalf("error = %v, called = %t", err, space.called)
	}
}

type fakeAttachmentSpace struct {
	called   bool
	err      error
	snapshot reserve.Snapshot
}

func (space *fakeAttachmentSpace) Snapshot(context.Context) (reserve.Snapshot, error) {
	space.called = true
	return space.snapshot, space.err
}
