package httpmetrics

import (
	"time"

	"github.com/prometheus/client_golang/prometheus"
)

type qualityMetrics struct {
	rtt, jitter, packetLoss, packetLossWindow, droppedFrames, sampleAge *prometheus.HistogramVec
	targetShortfall                                                     *prometheus.HistogramVec
	quality, adaptation, collection                                     *prometheus.CounterVec
	lastReport                                                          *prometheus.GaugeVec
}

func newQualityMetrics() qualityMetrics {
	labels := []string{"platform", "direction"}
	return qualityMetrics{
		rtt:              prometheus.NewHistogramVec(prometheus.HistogramOpts{Name: "voice_platform_client_screen_rtt_ms", Help: "Client-reported screen transport RTT in milliseconds; client-observed, not SFU truth.", Buckets: []float64{5, 10, 20, 40, 80, 120, 200, 400, 1000, 5000, 60000}}, labels),
		jitter:           prometheus.NewHistogramVec(prometheus.HistogramOpts{Name: "voice_platform_client_screen_jitter_ms", Help: "Client-reported screen transport jitter in milliseconds.", Buckets: []float64{1, 2, 5, 10, 20, 40, 80, 160, 500, 5000, 60000}}, labels),
		packetLoss:       prometheus.NewHistogramVec(prometheus.HistogramOpts{Name: "voice_platform_client_screen_packet_loss_percent", Help: "Client-reported packet loss percentage over the report's validated measurement window.", Buckets: []float64{0, .1, .5, 1, 2, 5, 10, 20, 50, 100}}, labels),
		packetLossWindow: prometheus.NewHistogramVec(prometheus.HistogramOpts{Name: "voice_platform_client_screen_packet_loss_window_ms", Help: "Validated client measurement window associated with each packet-loss percentage sample.", Buckets: []float64{9000, 10000, 11000, 12000}}, labels),
		droppedFrames:    prometheus.NewHistogramVec(prometheus.HistogramOpts{Name: "voice_platform_client_screen_dropped_frames", Help: "Client-reported dropped screen frames per bounded report interval.", Buckets: []float64{0, 1, 2, 5, 10, 25, 50, 100, 500, 1000, 1000000000}}, labels),
		sampleAge:        prometheus.NewHistogramVec(prometheus.HistogramOpts{Name: "voice_platform_client_screen_sample_age_ms", Help: "Age of client-side screen statistics when reported to the server.", Buckets: []float64{0, 50, 100, 250, 500, 1000, 2500, 5000, 10000, 15000}}, labels),
		targetShortfall:  prometheus.NewHistogramVec(prometheus.HistogramOpts{Name: "voice_platform_client_screen_target_shortfall_percent", Help: "Client-observed percentage below the reported target FPS or resolution; only recorded when both values are present.", Buckets: []float64{0, 1, 2, 5, 10, 20, 35, 50, 75, 100}}, []string{"platform", "direction", "kind"}),
		quality:          prometheus.NewCounterVec(prometheus.CounterOpts{Name: "voice_platform_client_screen_quality_total", Help: "Client-reported connection quality by fixed enum."}, []string{"platform", "direction", "quality"}),
		adaptation:       prometheus.NewCounterVec(prometheus.CounterOpts{Name: "voice_platform_client_screen_adaptation_total", Help: "Client-reported adaptation reasons by fixed enum."}, []string{"platform", "direction", "reason"}),
		collection:       prometheus.NewCounterVec(prometheus.CounterOpts{Name: "voice_platform_client_screen_collection_state_total", Help: "Client-reported media statistics availability and freshness reason by fixed enum."}, []string{"platform", "direction", "state"}),
		lastReport:       prometheus.NewGaugeVec(prometheus.GaugeOpts{Name: "voice_platform_client_screen_last_report_timestamp_seconds", Help: "Unix timestamp of the last authenticated client screen report; derive freshness as time() minus this value. Missing series means no report."}, labels),
	}
}

func (m qualityMetrics) collectors() []prometheus.Collector {
	return []prometheus.Collector{m.rtt, m.jitter, m.packetLoss, m.packetLossWindow, m.droppedFrames, m.sampleAge, m.targetShortfall, m.quality, m.adaptation, m.collection, m.lastReport}
}

func (m qualityMetrics) observeQuality(report ClientScreenReport, receivedAt time.Time) {
	labels := []string{report.Platform, report.Direction}
	m.lastReport.WithLabelValues(labels...).Set(float64(receivedAt.Unix()))
	observe := func(vector *prometheus.HistogramVec, value *float64) {
		if value != nil {
			vector.WithLabelValues(labels...).Observe(*value)
		}
	}
	observe(m.rtt, report.RTTMs)
	observe(m.jitter, report.JitterMs)
	observe(m.packetLoss, report.PacketLossPercent)
	observe(m.packetLossWindow, report.PacketLossWindowMs)
	if report.DroppedFrames != nil {
		m.droppedFrames.WithLabelValues(labels...).Observe(float64(*report.DroppedFrames))
	}
	observe(m.sampleAge, report.SampleAgeMs)
	if report.ConnectionQuality != "" {
		m.quality.WithLabelValues(report.Platform, report.Direction, report.ConnectionQuality).Inc()
	}
	if report.AdaptationReason != "" {
		m.adaptation.WithLabelValues(report.Platform, report.Direction, report.AdaptationReason).Inc()
	}
	if report.CollectionState != "" {
		m.collection.WithLabelValues(report.Platform, report.Direction, report.CollectionState).Inc()
	}
	actualFPS := report.EncodedFPS
	if report.Direction == "receiver" {
		actualFPS = report.PresentedFPS
		if actualFPS == nil {
			actualFPS = report.DecodedFPS
		}
	}
	if report.TargetFPS != nil && actualFPS != nil {
		m.targetShortfall.WithLabelValues(report.Platform, report.Direction, "fps").Observe(shortfallPercent(*report.TargetFPS, *actualFPS))
	}
	if report.TargetResolution != nil && report.FrameHeight != nil {
		m.targetShortfall.WithLabelValues(report.Platform, report.Direction, "resolution").Observe(shortfallPercent(*report.TargetResolution, float64(*report.FrameHeight)))
	}
}

func shortfallPercent(target, actual float64) float64 {
	if target <= 0 || actual >= target {
		return 0
	}
	return (target - actual) * 100 / target
}
