package rosterstreammetrics

import (
	"github.com/prometheus/client_golang/prometheus"
	"testing"
	"time"
)

func TestIdleMetricsInitializeZerosWithoutClaimingSuccess(t *testing.T) {
	registry := prometheus.NewRegistry()
	m := New(registry)
	values, err := registry.Gather()
	if err != nil {
		t.Fatal(err)
	}
	seen := map[string]bool{}
	for _, family := range values {
		switch family.GetName() {
		case "voice_platform_voice_roster_last_success_timestamp_seconds", "voice_platform_voice_roster_streams_active":
			seen[family.GetName()] = true
			if family.Metric[0].GetGauge().GetValue() != 0 {
				t.Fatalf("idle success asserted %s", family.GetName())
			}
		case "voice_platform_voice_roster_initial_total":
			if len(family.Metric) != 3 {
				t.Fatal("initial outcome zeros absent")
			}
			for _, point := range family.Metric {
				if point.GetCounter().GetValue() != 0 {
					t.Fatal("invented initial attempt")
				}
			}
		case "voice_platform_voice_roster_observation_enabled":
			if family.Metric[0].GetGauge().GetValue() != 1 {
				t.Fatal("observation disabled")
			}
		}
	}
	if len(seen) != 2 {
		t.Fatal("idle metrics absent")
	}
	m.Success()
	if m.fresh.rosterLatest <= 0 {
		t.Fatal("authorized success not recorded")
	}
	m.Call("ListRooms", "http_error", time.Millisecond)
	if m.fresh.latest["ListRooms"][1] != 0 {
		t.Fatal("failed call claimed last success")
	}
}
