package httpmetrics

import (
	"strings"
	"testing"
	"time"
)

func TestRecorderReconnectOutcomesHaveFixedLabels(t *testing.T) {
	recorder := New()
	for _, outcome := range []string{"replayed", "resync_required", "rejected", "user-11111111"} {
		recorder.ObserveRealtimeReconnectOutcome(outcome)
	}
	metrics := scrapeMetrics(recorder)
	for _, line := range []string{
		`voice_platform_realtime_reconnect_outcomes_total{outcome="replayed"} 1`,
		`voice_platform_realtime_reconnect_outcomes_total{outcome="resync_required"} 1`,
		`voice_platform_realtime_reconnect_outcomes_total{outcome="rejected"} 1`,
	} {
		if !strings.Contains(metrics, line) {
			t.Fatalf("metrics lack %q: %q", line, metrics)
		}
	}
	if strings.Contains(metrics, "user-11111111") {
		t.Fatalf("metrics disclosed caller-controlled label: %q", metrics)
	}
}

func TestRecorderObservesOnlyValidSuccessfulEventDelivery(t *testing.T) {
	recorder := New()
	recorder.ObserveRealtimeEventDeliveryLatency(25 * time.Millisecond)
	recorder.ObserveRealtimeEventDeliveryLatency(-time.Millisecond)
	metrics := scrapeMetrics(recorder)
	if !strings.Contains(metrics, "voice_platform_realtime_event_delivery_seconds_count 1") {
		t.Fatalf("event delivery count = %q", metrics)
	}
	for _, secret := range []string{"event_id", "dm_id", "account_id", "message_id"} {
		if strings.Contains(metrics, secret) {
			t.Fatalf("metrics leaked %q: %q", secret, metrics)
		}
	}
}
