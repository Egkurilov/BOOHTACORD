package httpmetrics

import (
	"errors"
	"math"
	"voice-platform/backend/internal/observability/report_client_screen/profile"
)

var ErrInvalidClientScreenReport = errors.New("invalid client screen report")

// ClientScreenReport contains only bounded measurements and fixed enums.
// It intentionally has no account, room, track, address, or content fields.
type ClientScreenReport struct {
	profile.Report
	Platform           string   `json:"platform"`
	Direction          string   `json:"direction"`
	State              string   `json:"state"`
	FrameWidth         *int     `json:"frame_width,omitempty"`
	FrameHeight        *int     `json:"frame_height,omitempty"`
	EncodedFPS         *float64 `json:"encoded_fps,omitempty"`
	DecodedFPS         *float64 `json:"decoded_fps,omitempty"`
	PresentedFPS       *float64 `json:"presented_fps,omitempty"`
	BitrateKbps        *float64 `json:"bitrate_kbps,omitempty"`
	JitterMs           *float64 `json:"jitter_ms,omitempty"`
	PacketsLost        *int64   `json:"packets_lost,omitempty"`
	DroppedFrames      *int64   `json:"dropped_frames,omitempty"`
	RTTMs              *float64 `json:"rtt_ms,omitempty"`
	PacketLossPercent  *float64 `json:"packet_loss_percent,omitempty"`
	PacketLossWindowMs *float64 `json:"packet_loss_window_ms,omitempty"`
	TargetResolution   *float64 `json:"target_resolution,omitempty"`
	TargetFPS          *float64 `json:"target_fps,omitempty"`
	SampleAgeMs        *float64 `json:"sample_age_ms,omitempty"`
	ConnectionQuality  string   `json:"connection_quality,omitempty"`
	AdaptationReason   string   `json:"adaptation_reason,omitempty"`
}

func (report ClientScreenReport) validate() error {
	switch report.Platform {
	case "ios_web", "android_web", "desktop_web", "android_native", "ios_native", "windows_native", "macos_native", "desktop_native":
	default:
		return ErrInvalidClientScreenReport
	}
	switch report.Direction {
	case "sender", "receiver", "connection":
	default:
		return ErrInvalidClientScreenReport
	}
	switch report.State {
	case "waiting_subscription", "waiting_first_frame", "playing", "stalled":
	default:
		return ErrInvalidClientScreenReport
	}
	for _, value := range []*float64{report.EncodedFPS, report.DecodedFPS, report.PresentedFPS} {
		if !validRange(value, 240) {
			return ErrInvalidClientScreenReport
		}
	}
	if !validRange(report.BitrateKbps, 100000) || !validRange(report.JitterMs, 60000) {
		return ErrInvalidClientScreenReport
	}
	if !validRange(report.RTTMs, 60000) {
		return ErrInvalidClientScreenReport
	}
	if report.PacketsLost != nil && (*report.PacketsLost < 0 || *report.PacketsLost > 1000000000) {
		return ErrInvalidClientScreenReport
	}
	if report.DroppedFrames != nil && (*report.DroppedFrames < 0 || *report.DroppedFrames > 1000000000) {
		return ErrInvalidClientScreenReport
	}
	if report.Direction == "sender" && (report.DecodedFPS != nil || report.PresentedFPS != nil) {
		return ErrInvalidClientScreenReport
	}
	if report.Direction == "receiver" && report.EncodedFPS != nil {
		return ErrInvalidClientScreenReport
	}
	if (report.FrameWidth == nil) != (report.FrameHeight == nil) {
		return ErrInvalidClientScreenReport
	}
	if report.FrameWidth != nil && (*report.FrameWidth < 1 || *report.FrameWidth > 8192 || *report.FrameHeight < 1 || *report.FrameHeight > 8192) {
		return ErrInvalidClientScreenReport
	}
	return report.validateMedia()
}

func validRange(value *float64, maximum float64) bool {
	return value == nil || (!math.IsNaN(*value) && !math.IsInf(*value, 0) && *value >= 0 && *value <= maximum)
}
