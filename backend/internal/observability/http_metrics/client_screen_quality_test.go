package httpmetrics

import (
	"net/http/httptest"
	"strings"
	"testing"
)

func TestClientScreenQualityAggregatesKeepFixedLabelsAndOmitMissingValues(t *testing.T) {
	recorder := New()
	presented, targetFPS := 15.0, 30.0
	targetResolution, sampleAge := 720.0, 1000.0
	packetLoss, packetWindow, rtt, jitter := 2.5, 10000.0, 120.0, 18.0
	dropped := int64(7)
	height := 360
	report := ClientScreenReport{
		Platform: "ios_web", Direction: "receiver", State: "playing",
		Measurement: Measurement{CollectionState: "stale"},
		FrameWidth:  intPointer(640), FrameHeight: &height, PresentedFPS: &presented,
		TargetFPS: &targetFPS, TargetResolution: &targetResolution, SampleAgeMs: &sampleAge,
		PacketLossPercent: &packetLoss, PacketLossWindowMs: &packetWindow,
		RTTMs: &rtt, JitterMs: &jitter, DroppedFrames: &dropped,
		ConnectionQuality: "POOR", AdaptationReason: "bandwidth",
	}
	if err := recorder.ObserveClientScreen(report); err != nil {
		t.Fatal(err)
	}
	scrape := httptest.NewRecorder()
	recorder.Handler().ServeHTTP(scrape, httptest.NewRequest("GET", "/metrics", nil))
	out := scrape.Body.String()
	for _, expected := range []string{
		`voice_platform_client_screen_rtt_ms_count{direction="receiver",platform="ios_web"} 1`,
		`voice_platform_client_screen_jitter_ms_count{direction="receiver",platform="ios_web"} 1`,
		`voice_platform_client_screen_packet_loss_percent_count{direction="receiver",platform="ios_web"} 1`,
		`voice_platform_client_screen_packet_loss_window_ms_count{direction="receiver",platform="ios_web"} 1`,
		`voice_platform_client_screen_dropped_frames_count{direction="receiver",platform="ios_web"} 1`,
		`voice_platform_client_screen_sample_age_ms_count{direction="receiver",platform="ios_web"} 1`,
		`voice_platform_client_screen_target_shortfall_percent_count{direction="receiver",kind="fps",platform="ios_web"} 1`,
		`voice_platform_client_screen_target_shortfall_percent_count{direction="receiver",kind="resolution",platform="ios_web"} 1`,
		`voice_platform_client_screen_target_shortfall_percent_sum{direction="receiver",kind="fps",platform="ios_web"} 50`,
		`voice_platform_client_screen_target_shortfall_percent_sum{direction="receiver",kind="resolution",platform="ios_web"} 50`,
		`voice_platform_client_screen_quality_total{direction="receiver",platform="ios_web",quality="POOR"} 1`,
		`voice_platform_client_screen_adaptation_total{direction="receiver",platform="ios_web",reason="bandwidth"} 1`,
		`voice_platform_client_screen_collection_state_total{direction="receiver",platform="ios_web",state="stale"} 1`,
		`voice_platform_client_screen_last_report_timestamp_seconds{direction="receiver",platform="ios_web"}`,
	} {
		if !strings.Contains(out, expected) {
			t.Fatalf("missing %q in metrics:\n%s", expected, out)
		}
	}
	for _, forbidden := range []string{"account_id", "channel_id", "track_id", "session_token", "room_id", "user_id"} {
		if strings.Contains(out, forbidden) {
			t.Fatalf("private field %q in metrics", forbidden)
		}
	}

	missing := ClientScreenReport{Platform: "android_web", Direction: "receiver", State: "playing"}
	if err := recorder.ObserveClientScreen(missing); err != nil {
		t.Fatal(err)
	}
	scrape = httptest.NewRecorder()
	recorder.Handler().ServeHTTP(scrape, httptest.NewRequest("GET", "/metrics", nil))
	out = scrape.Body.String()
	for _, absent := range []string{
		`voice_platform_client_screen_rtt_ms_count{direction="receiver",platform="android_web"}`,
		`voice_platform_client_screen_jitter_ms_count{direction="receiver",platform="android_web"}`,
		`voice_platform_client_screen_packet_loss_percent_count{direction="receiver",platform="android_web"}`,
		`voice_platform_client_screen_packet_loss_window_ms_count{direction="receiver",platform="android_web"}`,
		`voice_platform_client_screen_dropped_frames_count{direction="receiver",platform="android_web"}`,
		`voice_platform_client_screen_sample_age_ms_count{direction="receiver",platform="android_web"}`,
		`voice_platform_client_screen_target_shortfall_percent_count{direction="receiver",kind="fps",platform="android_web"}`,
	} {
		if strings.Contains(out, absent) {
			t.Fatalf("missing measurement was represented as a zero: %s", absent)
		}
	}
}

func intPointer(value int) *int { return &value }
