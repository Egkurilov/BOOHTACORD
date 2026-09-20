package httpmetrics

import (
	"strings"
	"testing"
)

func TestRecorderPublishesBoundedUploadFailureMetrics(t *testing.T) {
	recorder := New()
	recorder.UploadFailed("too_large")
	recorder.UploadFailed("/private/alice.png")

	metrics := scrapeMetrics(recorder)
	for _, line := range []string{
		`voice_platform_upload_failures_total{reason="too_large"} 1`,
		`voice_platform_upload_failures_total{reason="internal"} 1`,
	} {
		if !strings.Contains(metrics, line) {
			t.Fatalf("metrics lack %q: %q", line, metrics)
		}
	}
	if strings.Contains(metrics, "alice.png") || strings.Contains(metrics, "private/") {
		t.Fatalf("metrics leaked an upload detail: %q", metrics)
	}
}
