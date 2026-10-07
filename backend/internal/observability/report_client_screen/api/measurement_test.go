package reportscreenapi

import (
	"net/http/httptest"
	"strings"
	"testing"

	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
)

func TestIntervalReportAcceptedAndUnsafeIdentityRejected(t *testing.T) {
	recorder := httpmetrics.New()
	handler := NewSubmitHandler(recorder)
	valid := `{"platform":"desktop_web","direction":"sender","state":"playing","stats_source":"webrtc_interval","stats_window_ms":1000,"collection_state":"active","total_bitrate_kbps":2100,"selected_layer_bitrate_kbps":1800}`
	for _, tc := range []struct {
		body   string
		status int
	}{
		{valid, 204},
		{strings.Replace(valid, `"stats_window_ms":1000,`, "", 1), 400},
		{strings.Replace(valid, `"webrtc_interval"`, `"unsupported"`, 1), 400},
		{strings.Replace(valid, `"total_bitrate_kbps":2100`, `"total_bitrate_kbps":100001`, 1), 400},
		{strings.Replace(valid, `"collection_state":"active"`, `"rid":"private"`, 1), 400},
		{`{"platform":"desktop_web","direction":"receiver","state":"playing"}`, 204},
	} {
		w := httptest.NewRecorder()
		handler.ServeHTTP(w, httptest.NewRequest("POST", "/", strings.NewReader(tc.body)))
		if w.Code != tc.status {
			t.Fatalf("got %d want %d", w.Code, tc.status)
		}
	}
	for _, sample := range recorder.ClientScreenSnapshot() {
		attrs := measurementAttributes(sample.Report.Measurement)
		if sample.Report.Direction == "sender" && len(attrs) != 5 {
			t.Fatalf("missing forwarded fields: %d", len(attrs))
		}
		if sample.Report.Direction == "receiver" && len(attrs) != 0 {
			t.Fatal("legacy sample invented observations")
		}
	}
}
