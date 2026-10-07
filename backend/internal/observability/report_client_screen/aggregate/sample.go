package aggregate

import "math"

// Sample is anonymous. Callers must validate the existing report contract first.
// No session, user, room, track, codec or arbitrary diagnostic string is stored.
type Sample struct {
	Platform, Direction, State, Quality, Adaptation    string
	Encoded, Decoded, Presented, Bitrate, RTT, Jitter  *float64
	Loss, LossWindow, TargetFPS, TargetResolution, Age *float64
	Width, Height                                      *int
	Dropped                                            *int64
}

func (s Sample) bounded() bool {
	switch s.Platform {
	case "ios_web", "android_web", "desktop_web", "android_native", "ios_native", "windows_native", "macos_native", "desktop_native":
	default:
		return false
	}
	return s.Direction == "sender" || s.Direction == "receiver"
}

func number(v *float64, max float64) bool {
	return v != nil && !math.IsNaN(*v) && !math.IsInf(*v, 0) && *v >= 0 && *v <= max
}

func (s Sample) ageClass() string {
	if !number(s.Age, 15000) {
		return "legacy"
	}
	if *s.Age > 5000 {
		return "stale"
	}
	return "fresh"
}

func quality(value string) string {
	switch value {
	case "UNKNOWN", "EXCELLENT", "GOOD", "POOR", "LOST":
		return value
	}
	return "unreported"
}

func adaptation(value string) string {
	switch value {
	case "none", "cpu", "bandwidth", "other":
		return value
	}
	return "unreported"
}

func state(value string) string {
	switch value {
	case "waiting_subscription", "waiting_first_frame", "playing", "stalled":
		return value
	}
	return "unknown"
}
