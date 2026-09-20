package httpmetrics

import (
	"time"

	"github.com/prometheus/client_golang/prometheus"
)

type realtimeConnections struct {
	active prometheus.Gauge
	ready  prometheus.Histogram
	total  prometheus.Counter
}

func newRealtimeConnections() *realtimeConnections {
	return &realtimeConnections{
		active: prometheus.NewGauge(prometheus.GaugeOpts{Name: "voice_platform_realtime_connections_active", Help: "Accepted realtime WebSocket connections."}),
		ready:  prometheus.NewHistogram(prometheus.HistogramOpts{Name: "voice_platform_realtime_connection_ready_seconds", Help: "Time from WebSocket acceptance to ready response."}),
		total:  prometheus.NewCounter(prometheus.CounterOpts{Name: "voice_platform_realtime_connections_total", Help: "Accepted realtime WebSocket connections."}),
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
