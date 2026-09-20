package httpmetrics

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestRecorderPublishesAttachmentFilesystemMetrics(t *testing.T) {
	recorder := New()
	if err := recorder.RegisterAttachmentFilesystem(fakeAttachmentFilesystem{snapshot: AttachmentFilesystemSnapshot{AvailableBytes: 7, TotalBytes: 11}}); err != nil {
		t.Fatal(err)
	}
	metrics := scrapeMetrics(recorder)
	for _, line := range []string{
		"voice_platform_attachment_filesystem_available_bytes 7",
		"voice_platform_attachment_filesystem_total_bytes 11",
		"voice_platform_attachment_filesystem_snapshot_success 1",
	} {
		if !strings.Contains(metrics, line) {
			t.Fatalf("metrics lack %q: %q", line, metrics)
		}
	}
	if strings.Contains(metrics, "path=") || strings.Contains(metrics, "attachment-root") {
		t.Fatalf("metrics leaked a filesystem identity: %q", metrics)
	}
}

func TestRecorderReportsAttachmentFilesystemSnapshotFailure(t *testing.T) {
	recorder := New()
	if err := recorder.RegisterAttachmentFilesystem(fakeAttachmentFilesystem{err: errors.New("attachment-root unavailable")}); err != nil {
		t.Fatal(err)
	}
	metrics := scrapeMetrics(recorder)
	for _, line := range []string{
		"voice_platform_attachment_filesystem_available_bytes 0",
		"voice_platform_attachment_filesystem_total_bytes 0",
		"voice_platform_attachment_filesystem_snapshot_success 0",
	} {
		if !strings.Contains(metrics, line) {
			t.Fatalf("metrics lack %q: %q", line, metrics)
		}
	}
	if strings.Contains(metrics, "attachment-root unavailable") {
		t.Fatalf("metrics leaked a filesystem error: %q", metrics)
	}
}

func TestRecorderRejectsInvalidOrDuplicateAttachmentFilesystemSource(t *testing.T) {
	recorder := New()
	if err := recorder.RegisterAttachmentFilesystem(nil); !errors.Is(err, ErrInvalidAttachmentFilesystemSource) {
		t.Fatalf("nil source error = %v", err)
	}
	if err := recorder.RegisterAttachmentFilesystem(fakeAttachmentFilesystem{}); err != nil {
		t.Fatal(err)
	}
	if err := recorder.RegisterAttachmentFilesystem(fakeAttachmentFilesystem{}); !errors.Is(err, ErrAttachmentFilesystemAlreadyRegistered) {
		t.Fatalf("duplicate source error = %v", err)
	}
}

func scrapeMetrics(recorder *Recorder) string {
	scrape := httptest.NewRecorder()
	recorder.Handler().ServeHTTP(scrape, httptest.NewRequest(http.MethodGet, "/metrics", nil))
	return scrape.Body.String()
}

type fakeAttachmentFilesystem struct {
	err      error
	snapshot AttachmentFilesystemSnapshot
}

func (filesystem fakeAttachmentFilesystem) Snapshot(context.Context) (AttachmentFilesystemSnapshot, error) {
	return filesystem.snapshot, filesystem.err
}
