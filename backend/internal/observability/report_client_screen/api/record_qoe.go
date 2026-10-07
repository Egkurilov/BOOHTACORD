package reportscreenapi

import (
	"context"

	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
	"voice-platform/backend/internal/observability/report_client_screen/aggregate"
)

func recordQoE(ctx context.Context, metrics *aggregate.Metrics, r httpmetrics.ClientScreenReport) {
	metrics.Observe(ctx, aggregate.Sample{
		Platform: r.Platform, Direction: r.Direction, State: r.State,
		Encoded: r.EncodedFPS, Decoded: r.DecodedFPS, Presented: r.PresentedFPS,
		Bitrate: r.BitrateKbps, RTT: r.RTTMs, Jitter: r.JitterMs,
		Loss: r.PacketLossPercent, LossWindow: r.PacketLossWindowMs,
		TargetFPS: r.TargetFPS, TargetResolution: r.TargetResolution, Age: r.SampleAgeMs,
		Width: r.FrameWidth, Height: r.FrameHeight, Dropped: r.DroppedFrames,
		Quality: r.ConnectionQuality, Adaptation: r.AdaptationReason,
	})
}
