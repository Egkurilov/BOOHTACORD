package httpmetrics

import (
	"time"

	"github.com/prometheus/client_golang/prometheus"
)

type realtimeConnections struct {
	active               prometheus.Gauge
	ready                prometheus.Histogram
	total                prometheus.Counter
	revalidation         prometheus.Histogram
	revalidationFailures prometheus.Counter
	rejected             prometheus.Counter
}

func newRealtimeConnections() *realtimeConnections {
	return &realtimeConnections{
		active:               prometheus.NewGauge(prometheus.GaugeOpts{Name: "voice_platform_realtime_connections_active", Help: "Accepted realtime WebSocket connections."}),
		ready:                prometheus.NewHistogram(prometheus.HistogramOpts{Name: "voice_platform_realtime_connection_ready_seconds", Help: "Time from WebSocket acceptance to ready response."}),
		total:                prometheus.NewCounter(prometheus.CounterOpts{Name: "voice_platform_realtime_connections_total", Help: "Accepted realtime WebSocket connections."}),
		revalidation:         prometheus.NewHistogram(prometheus.HistogramOpts{Name: "voice_platform_realtime_session_revalidation_seconds", Help: "Duration of realtime session revalidation calls."}),
		revalidationFailures: prometheus.NewCounter(prometheus.CounterOpts{Name: "voice_platform_realtime_session_revalidation_failures_total", Help: "Realtime session revalidation failures."}),
		rejected:             prometheus.NewCounter(prometheus.CounterOpts{Name: "voice_platform_realtime_connections_rejected_total", Help: "Realtime connection attempts rejected by admission quotas."}),
	}
}

func (recorder *Recorder) RealtimeConnectionOpened() {
	recorder.realtime.active.Inc()
	recorder.realtime.total.Inc()
}

func (recorder *Recorder) ObserveRealtimeConnectionReady(duration time.Duration) {
	recorder.realtime.ready.Observe(duration.Seconds())
}

func (recorder *Recorder) RealtimeConnectionClosed() { recorder.realtime.active.Dec() }

func (recorder *Recorder) ObserveRealtimeSessionRevalidation(duration time.Duration, valid bool) {
	recorder.realtime.revalidation.Observe(duration.Seconds())
	if !valid {
		recorder.realtime.revalidationFailures.Inc()
	}
}

func (recorder *Recorder) ObserveRealtimeConnectionRejected() { recorder.realtime.rejected.Inc() }
