package reportscreenapi

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
)

type fakeRecorder struct {
	reports []httpmetrics.ClientScreenReport
	samples []httpmetrics.ClientScreenSample
}

func (fake *fakeRecorder) ObserveClientScreen(report httpmetrics.ClientScreenReport) error {
	fake.reports = append(fake.reports, report)
	return nil
}
func (fake *fakeRecorder) ClientScreenSnapshot() []httpmetrics.ClientScreenSample {
	return fake.samples
}

func TestSubmitAcceptsOnlyStrictBoundedMeasurements(t *testing.T) {
	recorder := httpmetrics.New()
	handler := NewSubmitHandler(recorder)
	for _, body := range []string{
		`{"platform":"ios_web","direction":"receiver","state":"playing","account_id":"private"}`,
		`{"platform":"ios_web","direction":"receiver","state":"playing","frame_width":540}`,
		`{"platform":"ios_web","direction":"receiver","state":"playing"}{"extra":true}`,
		strings.Repeat(" ", 2049),
	} {
		response := httptest.NewRecorder()
		handler.ServeHTTP(response, httptest.NewRequest(http.MethodPost, "/", strings.NewReader(body)))
		if response.Code != http.StatusBadRequest {
			t.Fatalf("accepted malformed report with status %d", response.Code)
		}
	}
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, httptest.NewRequest(http.MethodPost, "/", bytes.NewBufferString(`{"platform":"ios_web","direction":"receiver","state":"waiting_first_frame","frame_width":540,"frame_height":1170}`)))
	samples := recorder.ClientScreenSnapshot()
	if response.Code != http.StatusNoContent || len(samples) != 1 || samples[0].Report.FrameWidth == nil || *samples[0].Report.FrameWidth != 540 {
		t.Fatalf("valid report status=%d samples=%+v", response.Code, samples)
	}
}

func TestAdminSnapshotContainsOnlyAnonymousSamples(t *testing.T) {
	recorder := &fakeRecorder{samples: []httpmetrics.ClientScreenSample{{Report: httpmetrics.ClientScreenReport{Platform: "ios_web", Direction: "receiver", State: "playing"}, SampledAtUTC: "2026-09-26T13:00:00Z"}}}
	response := httptest.NewRecorder()
	NewAdminHandler(recorder).ServeHTTP(response, httptest.NewRequest(http.MethodGet, "/", nil))
	if response.Code != http.StatusOK || !strings.Contains(response.Body.String(), `"ios_web"`) {
		t.Fatalf("snapshot status=%d body=%s", response.Code, response.Body.String())
	}
	for _, forbidden := range []string{"account_id", "channel_id", "track_id", "session_token"} {
		if strings.Contains(response.Body.String(), forbidden) {
			t.Fatalf("snapshot disclosed %q", forbidden)
		}
	}
}
