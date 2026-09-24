package httpmetrics

import (
	"time"

	"github.com/prometheus/client_golang/prometheus"
)

func newRealtimeReconnectOutcomes() *prometheus.CounterVec {
	return prometheus.NewCounterVec(prometheus.CounterOpts{
		Name: "voice_platform_realtime_reconnect_outcomes_total",
		Help: "Realtime resume attempts by fixed server-determined outcome.",
	}, []string{"outcome"})
}

func newRealtimeEventDeliveryLatency() prometheus.Histogram {
	return prometheus.NewHistogram(prometheus.HistogramOpts{
		Name:    "voice_platform_realtime_event_delivery_seconds",
		Help:    "Time from published event occurrence to successful WebSocket write.",
		Buckets: []float64{0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10},
	})
}

func (recorder *Recorder) ObserveRealtimeReconnectOutcome(outcome string) {
	switch outcome {
	case "replayed", "resync_required", "rejected":
		recorder.reconnectOutcomes.WithLabelValues(outcome).Inc()
	}
}

func (recorder *Recorder) ObserveRealtimeEventDeliveryLatency(duration time.Duration) {
	if duration < 0 {
		return
	}
	recorder.eventDeliveryLatency.Observe(duration.Seconds())
}
