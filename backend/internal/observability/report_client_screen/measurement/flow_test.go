package measurement

import "testing"

func TestFlowPreservesLegacyAndRejectsInventedPresentation(t *testing.T) {
	if !FlowValid("receiver", map[string]any{"app.media.presented_fps": 0.0}) {
		t.Fatal("legacy rejected")
	}
	fields := map[string]any{"app.media.presentation_source": "unsupported"}
	if !FlowValid("receiver", fields) {
		t.Fatal("unsupported metadata rejected")
	}
	fields["app.media.presented_fps"] = 0.0
	if FlowValid("receiver", fields) {
		t.Fatal("unsupported source invented zero FPS")
	}
	fields = map[string]any{"app.media.freeze_count": 1.5, "app.media.stats_source": "webrtc_interval"}
	if FlowValid("receiver", fields) {
		t.Fatal("fractional freeze counter accepted")
	}
}

func TestFlowRejectsDirectionlessIntervalsAndSenderPresentation(t *testing.T) {
	fields := map[string]any{"app.media.nack_per_second": 10.0, "app.media.stats_window_ms": 1000.0, "app.media.stats_source": "webrtc_interval"}
	if FlowValid("", fields) {
		t.Fatal("feedback interval accepted without direction")
	}
	fields = map[string]any{"app.media.presented_fps": 30.0, "app.media.presentation_source": "web_rvfc"}
	if FlowValid("sender", fields) {
		t.Fatal("sender claimed receiver presentation")
	}
	if !FlowValid("receiver", fields) {
		t.Fatal("receiver presentation rejected")
	}
	if !FlowValid("", map[string]any{}) {
		t.Fatal("non-media legacy flow rejected")
	}
}
