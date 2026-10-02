package profile

import "math"

// Report contains only bounded capture measurements and fixed guard outcomes.
type Report struct {
	ProfileCheckStatus    string   `json:"profile_check_status,omitempty"`
	ProfileCheckReason    string   `json:"profile_check_reason,omitempty"`
	ProfileRepairAttempts *int     `json:"profile_repair_attempts,omitempty"`
	CaptureWidth          *int     `json:"capture_width,omitempty"`
	CaptureHeight         *int     `json:"capture_height,omitempty"`
	CaptureFPS            *float64 `json:"capture_fps,omitempty"`
}

func (r Report) Valid(direction string) bool {
	if r.ProfileCheckStatus == "" {
		return r.ProfileCheckReason == "" && r.ProfileRepairAttempts == nil && r.CaptureWidth == nil && r.CaptureHeight == nil && r.CaptureFPS == nil
	}
	if direction != "sender" || r.ProfileRepairAttempts == nil || *r.ProfileRepairAttempts < 0 || *r.ProfileRepairAttempts > 1 {
		return false
	}
	switch r.ProfileCheckStatus {
	case "checking", "matched", "adapted", "inactive", "drift", "repairing", "failed":
	default:
		return false
	}
	switch r.ProfileCheckReason {
	case "none", "capture", "configuration", "resolution", "unavailable":
	default:
		return false
	}
	if (r.CaptureWidth == nil) != (r.CaptureHeight == nil) {
		return false
	}
	if r.CaptureWidth != nil && (*r.CaptureWidth < 1 || *r.CaptureWidth > 8192 || *r.CaptureHeight < 1 || *r.CaptureHeight > 8192) {
		return false
	}
	return r.CaptureFPS == nil || (!math.IsNaN(*r.CaptureFPS) && !math.IsInf(*r.CaptureFPS, 0) && *r.CaptureFPS >= 0 && *r.CaptureFPS <= 240)
}
