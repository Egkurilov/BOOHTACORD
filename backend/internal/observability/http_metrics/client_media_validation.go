package httpmetrics

func (report ClientScreenReport) validateMedia() error {
	if !report.Report.Valid(report.Direction) {
		return ErrInvalidClientScreenReport
	}
	if !validRange(report.PacketLossPercent, 100) || !validRange(report.PacketLossWindowMs, 12000) || !validRange(report.SampleAgeMs, 15000) {
		return ErrInvalidClientScreenReport
	}
	if (report.PacketLossPercent == nil) != (report.PacketLossWindowMs == nil) || (report.PacketLossWindowMs != nil && *report.PacketLossWindowMs < 9000) {
		return ErrInvalidClientScreenReport
	}
	if report.TargetResolution != nil && *report.TargetResolution != 720 && *report.TargetResolution != 1080 && *report.TargetResolution != 1440 {
		return ErrInvalidClientScreenReport
	}
	if report.TargetFPS != nil && *report.TargetFPS != 15 && *report.TargetFPS != 30 && *report.TargetFPS != 60 {
		return ErrInvalidClientScreenReport
	}
	switch report.ConnectionQuality {
	case "", "UNKNOWN", "EXCELLENT", "GOOD", "POOR", "LOST":
	default:
		return ErrInvalidClientScreenReport
	}
	switch report.AdaptationReason {
	case "", "none", "cpu", "bandwidth", "other":
	default:
		return ErrInvalidClientScreenReport
	}
	if report.Direction == "connection" && (report.FrameWidth != nil || report.EncodedFPS != nil || report.DecodedFPS != nil || report.PresentedFPS != nil || report.BitrateKbps != nil || report.TargetResolution != nil || report.TargetFPS != nil || report.PacketLossPercent != nil) {
		return ErrInvalidClientScreenReport
	}
	return nil
}
