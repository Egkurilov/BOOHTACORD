package httpmetrics

import (
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestClientScreenReportIsBoundedAndExpires(t *testing.T) {
	recorder := New()
	now := time.Date(2026, 9, 26, 13, 0, 0, 0, time.UTC)
	recorder.clientScreen.now = func() time.Time { return now }
	presented, decoded, bitrate := 0.0, 26.5, 1100.0
	report := ClientScreenReport{Platform: "ios_web", Direction: "receiver", State: "waiting_first_frame", PresentedFPS: &presented, DecodedFPS: &decoded, BitrateKbps: &bitrate}
	if err := recorder.ObserveClientScreen(report); err != nil {
		t.Fatal(err)
	}
	samples := recorder.ClientScreenSnapshot()
	if len(samples) != 1 || samples[0].Report.DecodedFPS == nil || *samples[0].Report.DecodedFPS != decoded {
		t.Fatalf("unexpected samples: %+v", samples)
	}
	scrape := httptest.NewRecorder()
	recorder.Handler().ServeHTTP(scrape, httptest.NewRequest("GET", "/metrics", nil))
	for _, expected := range []string{"voice_platform_client_screen_reports_total", "platform=\"ios_web\"", "state=\"waiting_first_frame\"", "voice_platform_client_screen_fps"} {
		if !strings.Contains(scrape.Body.String(), expected) {
			t.Fatalf("missing %q in metrics", expected)
		}
	}
	for _, forbidden := range []string{"account_id", "channel_id", "track_id", "session_token", "candidate"} {
		if strings.Contains(scrape.Body.String(), forbidden) {
			t.Fatalf("private field %q in metrics", forbidden)
		}
	}
	now = now.Add(61 * time.Second)
	if got := recorder.ClientScreenSnapshot(); len(got) != 0 {
		t.Fatalf("expired sample retained: %+v", got)
	}
}

func TestClientScreenReportRejectsUnknownAndInvalidValues(t *testing.T) {
	recorder := New()
	bad := -1.0
	tooHigh := 241.0
	for _, report := range []ClientScreenReport{
		{Platform: "private-account", Direction: "receiver", State: "playing"},
		{Platform: "ios_web", Direction: "private-direction", State: "playing"},
		{Platform: "ios_web", Direction: "receiver", State: "private-state"},
		{Platform: "ios_web", Direction: "receiver", State: "playing", PresentedFPS: &bad},
		{Platform: "ios_web", Direction: "receiver", State: "playing", EncodedFPS: &tooHigh},
	} {
		if err := recorder.ObserveClientScreen(report); err == nil {
			t.Fatalf("accepted invalid report: %+v", report)
		}
	}
	if got := recorder.ClientScreenSnapshot(); len(got) != 0 {
		t.Fatalf("invalid reports retained: %+v", got)
	}
}
