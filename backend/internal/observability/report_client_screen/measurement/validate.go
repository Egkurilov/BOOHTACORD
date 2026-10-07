package measurement

import (
	"math"
	"slices"
)

func (r Report) Valid(direction string) bool {
	for key, value := range r.Numbers() {
		if value == nil {
			continue
		}
		maximum := 60000.0
		switch key {
		case "total_bitrate_kbps", "selected_layer_bitrate_kbps", "retransmitted_bitrate_kbps":
			maximum = 100000
		case "nack_per_second", "pli_per_second", "fir_per_second":
			maximum = 1000000
		case "first_frame_ms", "freeze_duration_ms":
			maximum = 86400000
		case "stats_window_ms":
			maximum = 10000
		}
		if math.IsNaN(*value) || math.IsInf(*value, 0) || *value < 0 || *value > maximum {
			return false
		}
	}
	if r.FreezeCount != nil && (*r.FreezeCount < 0 || *r.FreezeCount > 1000000000) {
		return false
	}
	if r.StatsWindowMs != nil && (*r.StatsWindowMs <= 0 || r.StatsSource != "webrtc_interval") {
		return false
	}
	if !slices.Contains([]string{"", "active", "inactive", "sdk_paused", "hidden", "reconnecting", "unavailable", "stale", "unknown", "no_subscriber"}, r.CollectionState) {
		return false
	}
	if !slices.Contains([]string{"", "web_rvfc", "unsupported"}, r.PresentationSource) || !slices.Contains([]string{"", "webrtc_interval", "unsupported"}, r.StatsSource) {
		return false
	}
	interval := []*float64{r.TotalBitrateKbps, r.SelectedLayerBitrateKbps, r.RetransmittedBitrateKbps, r.EncodeMsPerFrame, r.DecodeMsPerFrame, r.JitterBufferMsPerFrame, r.NackPerSecond, r.PliPerSecond, r.FirPerSecond}
	for _, value := range interval {
		if value != nil && (r.StatsWindowMs == nil || r.StatsSource != "webrtc_interval") {
			return false
		}
	}
	sender := []*float64{r.TotalBitrateKbps, r.SelectedLayerBitrateKbps, r.RetransmittedBitrateKbps, r.EncodeMsPerFrame}
	for _, value := range sender {
		if value != nil && direction != "sender" {
			return false
		}
	}
	receiver := []*float64{r.DecodeMsPerFrame, r.JitterBufferMsPerFrame, r.FirstFrameMs, r.FreezeDurationMs}
	for _, value := range receiver {
		if value != nil && direction != "receiver" {
			return false
		}
	}
	if r.FreezeCount != nil && direction != "receiver" {
		return false
	}
	if (r.FreezeCount != nil || r.FreezeDurationMs != nil) && r.StatsSource != "webrtc_interval" {
		return false
	}
	if r.FirstFrameMs != nil && r.PresentationSource != "web_rvfc" {
		return false
	}
	if direction == "connection" {
		for _, value := range r.Numbers() {
			if value != nil {
				return false
			}
		}
	}
	return true
}
