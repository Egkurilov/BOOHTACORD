package measurement

import (
	"math"
	"testing"
)

func ptr(value float64) *float64 { return &value }

func TestLegacyAndObservedIntervals(t *testing.T) {
	if !(Report{}).Valid("sender") {
		t.Fatal("legacy rejected")
	}
	r := Report{StatsSource: "webrtc_interval", StatsWindowMs: ptr(1000), TotalBitrateKbps: ptr(2100), SelectedLayerBitrateKbps: ptr(1800), CollectionState: "active"}
	if !r.Valid("sender") {
		t.Fatal("valid sender rejected")
	}
	r.StatsWindowMs = nil
	if r.Valid("sender") {
		t.Fatal("ungrounded interval accepted")
	}
	r.StatsWindowMs = ptr(1000)
	if r.Valid("receiver") {
		t.Fatal("sender fields accepted for receiver")
	}
	r.StatsSource = "unsupported"
	if r.Valid("sender") {
		t.Fatal("unsupported source invented numbers")
	}
}

func TestDurationsAreBoundedAndPresentationIsHonest(t *testing.T) {
	count := int64(2)
	r := Report{FirstFrameMs: ptr(0), FreezeCount: &count, FreezeDurationMs: ptr(120), PresentationSource: "web_rvfc", StatsSource: "webrtc_interval"}
	if !r.Valid("receiver") {
		t.Fatal("receiver observation rejected")
	}
	if r.Valid("sender") {
		t.Fatal("receiver fields accepted for sender")
	}
	for _, value := range []float64{-1, math.NaN(), math.Inf(1), 86400001} {
		r.FirstFrameMs = ptr(value)
		if r.Valid("receiver") {
			t.Fatal("bad duration accepted")
		}
	}
	r = Report{StatsWindowMs: ptr(0), StatsSource: "webrtc_interval"}
	if r.Valid("receiver") {
		t.Fatal("zero window accepted")
	}
	r = Report{CollectionState: "arbitrary-person"}
	if r.Valid("receiver") {
		t.Fatal("unbounded state accepted")
	}
	r = Report{PresentationSource: "monitor_scanout"}
	if r.Valid("receiver") {
		t.Fatal("fictional provenance accepted")
	}
}

func TestFeedbackIntervalsRequireAnExplicitMediaDirection(t *testing.T) {
	r := Report{StatsSource: "webrtc_interval", StatsWindowMs: ptr(1000), NackPerSecond: ptr(10), PliPerSecond: ptr(2), FirPerSecond: ptr(1)}
	for _, direction := range []string{"", "connection", "arbitrary"} {
		if r.Valid(direction) {
			t.Fatalf("new interval accepted direction %q", direction)
		}
	}
	for _, direction := range []string{"sender", "receiver"} {
		if !r.Valid(direction) {
			t.Fatalf("valid feedback interval rejected direction %q", direction)
		}
	}
	if !(Report{}).Valid("") || !(Report{}).Valid("connection") || !(Report{StatsSource: "unsupported", CollectionState: "unknown"}).Valid("") {
		t.Fatal("legacy or enum-only metadata compatibility lost")
	}
}

func TestPresentationProvenanceBelongsOnlyToReceiver(t *testing.T) {
	for _, source := range []string{"web_rvfc", "unsupported"} {
		r := Report{PresentationSource: source}
		if !r.Valid("receiver") {
			t.Fatalf("receiver metadata rejected: %s", source)
		}
		for _, direction := range []string{"", "sender", "connection"} {
			if r.Valid(direction) {
				t.Fatalf("presentation metadata accepted for %q", direction)
			}
		}
	}
}
